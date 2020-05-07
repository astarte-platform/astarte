/*
   This file is part of Astarte.

   Copyright 2017 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import ReactDOM from "react-dom";
import { createBrowserHistory } from "history";
import { getRouter } from "../react/Router.js";
import AstarteClient from "../react/AstarteClient.js";

require("./styles/main.scss");

const $ = require("jquery");

let reactHistory = null;
let dashboardConfig = null;
let phoenixSocket = null;
let channel = null;
let app;

let astarteClient = null;

$.getJSON("/user-config/config.json", function(result) {
  dashboardConfig = result;
})
  .fail(function(jqXHR, textStatus, errorThrown) {
    console.log(
      "Astarte dashboard configuration file (config.json) is missing. Starting in editor only mode"
    );
  })
  .always(function() {
    let parameters = {
      config: dashboardConfig,
      previousSession: localStorage.session || null
    };

    //init app
    app = require("../elm/Main").Elm.Main.init({ flags: parameters });

    astarteClient = getAstarteClient(localStorage.session);

    /* begin Elm ports */
    app.ports.storeSession.subscribe(function(session) {
      console.log("storing session");
      localStorage.session = session;

      // update with new session data
      astarteClient = getAstarteClient(session);
    });

    app.ports.loadReactPage.subscribe(loadPage);
    app.ports.unloadReactPage.subscribe(clearReact);

    app.ports.listenToDeviceEvents.subscribe(watchDeviceEvents);

    window.addEventListener(
      "storage",
      function(event) {
        if (event.storageArea === localStorage && event.key === "session") {
          console.log("local session changed");
          app.ports.onSessionChange.send(event.newValue);
        }
      },
      false
    );
    /* end Elm ports */
  });

function watchDeviceEvents(params) {
  const { deviceId } = params;
  const salt = Math.floor(Math.random() * 10000);
  const roomName = `dashboard_${deviceId}_${salt}`;
  astarteClient.joinRoom(roomName)
    .then(() => {
      sendInfoMessage(`Joined room for device ${params.deviceId}`);

      astarteClient.listenForEvents(roomName, (payload) => {
        app.ports.onDeviceEventReceived.send(payload);
      });

      const connectionTriggerPayload = {
        name: `connectiontrigger-${deviceId}`,
        device_id: deviceId,
        simple_trigger: {
          type: "device_trigger",
          on: "device_connected",
          device_id: deviceId
        }
      };

      const disconnectionTriggerPayload = {
        name: `disconnectiontrigger-${deviceId}`,
        device_id: deviceId,
        simple_trigger: {
          type: "device_trigger",
          on: "device_disconnected",
          device_id: deviceId
        }
      };

      const dataTriggerPayload = {
        name: `datatrigger-${deviceId}`,
        device_id: deviceId,
        simple_trigger: {
          type: "data_trigger",
          on: "incoming_data",
          interface_name: "*",
          value_match_operator: "*",
          match_path: "/*"
        }
      };

      astarteClient.registerVolatileTrigger(roomName, connectionTriggerPayload)
        .then(() => { sendInfoMessage("Watching for device connection events") })
        .catch((err) => { sendErrorMessage("Coulnd't watch for device connection events") });

      astarteClient.registerVolatileTrigger(roomName, disconnectionTriggerPayload)
        .then(() => { sendInfoMessage("Watching for device disconnection events") })
        .catch((err) => { sendErrorMessage("Coulnd't watch for device disconnection events") });

      astarteClient.registerVolatileTrigger(roomName, dataTriggerPayload)
        .then(() => { sendInfoMessage("Watching for device data events") })
        .catch((err) => { sendErrorMessage("Coulnd't watch for device data events") });
    })
    .catch((err) => {
      sendErrorMessage(`Couldn't join device ${deviceId} room`);
    });
}

function sendErrorMessage(errorMessage) {
  app.ports.onDeviceEventReceived.send({
    message: errorMessage,
    level: "error",
    timestamp: Date.now()
  });
}

function sendInfoMessage(infoMessage) {
  app.ports.onDeviceEventReceived.send({
    message: infoMessage,
    level: "info",
    timestamp: Date.now()
  });
}

function loadPage(page) {
  let elem = document.getElementById("react-page");
  if (elem) {
    console.log("React already initialized, skipping");
    reactHistory.push({ pathname: page.url });
    return;
  }

  let pageNode = document.getElementById("inner-page");

  if (!pageNode) {
    console.log("Elm side is not ready yet. retry later...");
    setTimeout(function() {
      loadPage(page);
    }, 100);
    return;
  }

  let node = document.createElement("div");
  node.id = "react-page";
  pageNode.appendChild(node);

  reactHistory = createBrowserHistory();

  const reactApp = getRouter(reactHistory, astarteClient, noMatchFallback);
  ReactDOM.render(reactApp, document.getElementById("react-page"));
}

function clearReact() {
  let elem = document.getElementById("react-page");
  if (elem) {
    elem.remove();
  }
}

function noMatchFallback(url) {
  app.ports.onPageRequested.send(url);
}

function getAstarteClient(session) {
  if (!session || session == "null") {
    return null;
  }

  const config = JSON.parse(session).api_config;
  const protocol = config.secure_connection ? "https://" : "http://";
  const astarteConfig = {
    realm: config.realm,
    token: config.token,
    secureConnection: config.secure_connection,
    realmManagementUrl: protocol + config.realm_management_url,
    appengineUrl: protocol + config.appengine_url,
    pairingUrl: protocol + config.pairing_url,
    onSocketError: (() => { sendErrorError("Astarte channels communication error") }),
    onSocketClose: (() => { sendErrorError("Lost connection with the Astarte channel") })
  };

  return new AstarteClient(astarteConfig);
}
