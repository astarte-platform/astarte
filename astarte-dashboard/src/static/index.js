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

require("./styles/main.scss");

const $ = require("jquery");
const { Socket } = require("phoenix");

let reactHistory = null;
let dashboardConfig = null;
let phoenixSocket = null;
let channel = null;
let app;

$.getJSON("/user-config/config.json", function(result) {
  if (result.realm_management_api_url) {
    dashboardConfig = result;
  } else {
    console.log(
      "Invalid Astarte dashboard configuration file. Starting in editor only mode"
    );
  }
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

    /* begin Elm ports */
    app.ports.storeSession.subscribe(function(session) {
      console.log("storing session");
      localStorage.session = session;
    });

    app.ports.loadReactPage.subscribe(loadPage);
    app.ports.unloadReactPage.subscribe(clearReact);

    app.ports.listenToDeviceEvents.subscribe(connectToChannel);

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

function openSocket(params) {
  console.log("opening web socket");

  if (phoenixSocket) {
    console.log("web socket already opened");
    return;
  }

  if (!params.appengineUrl) {
    console.log("no appengine url provided");
    return;
  }

  let protocol;
  if (params.secureConnection) {
    protocol = "wss";
  } else {
    protocol = "ws";
  }

  let socketUrl = `${protocol}://${params.appengineUrl}/socket`;
  socketUrl = socketUrl.replace("/v1", ""); // TODO workaraound! remove when fixed in 0.11

  let socketParams = { params: { realm: params.realm, token: params.token } };
  phoenixSocket = new Socket(socketUrl, socketParams);
  phoenixSocket.onError(socketErrorHandler);
  phoenixSocket.onClose(socketCloseHandler);
  phoenixSocket.onOpen(() => console.log("Socket opened"));
  phoenixSocket.connect();
}

function connectToChannel(params) {
  console.log(`joining room for device id ${params.deviceId}`);

  if (!phoenixSocket) {
    openSocket(params);
  }

  if (channel) {
    // already in a room, leave and retry
    console.log("already in a room");
    channel
      .leave()
      .receive("ok", () => {
        channel = null;
        connectToChannel(params);
      })
      .receive("error", resp => {
        console.log("Unable to leave previous room", resp);
      });

    return;
  }

  // This should be unique and you should have JOIN and WATCH permissions for it in the JWT
  let salt = Math.floor(Math.random() * 10000);
  let room_name = `dashboard_${params.deviceId}_${salt}`;
  channel = phoenixSocket.channel(`rooms:${params.realm}:${room_name}`, {});

  channel
    .join()
    .receive("ok", resp => {
      roomJoinedHandler(resp, params);
    })
    .receive("error", resp => {
      console.log("Unable to join", resp);
      app.ports.onDeviceEventReceived.send({
        message: `Error joining room for device ${params.deviceId}`,
        level: "error",
        timestamp: Date.now()
      });
    });
}

function socketErrorHandler() {
  console.log("There was an error with the connection!");
  app.ports.onDeviceEventReceived.send({
    message: "Phoenix socket connection error",
    level: "error",
    timestamp: Date.now()
  });
}

function socketCloseHandler() {
  console.log("The connection dropped");
  phoenixSocket = null;
}

function roomJoinedHandler(resp, params) {
  console.log("Joined successfully", resp);
  app.ports.onDeviceEventReceived.send({
    message: `Joined room for device ${params.deviceId}`,
    level: "info",
    timestamp: Date.now()
  });

  // triggers
  installConnectionTrigger(params.deviceId);
  installDisconnectionTrigger(params.deviceId);

  params.interfaces.forEach(installedInterface => {
    installInterfaceTrigger(
      params.deviceId,
      installedInterface.name,
      installedInterface.major
    );
  });

  // events
  channel.on("new_event", payload => {
    app.ports.onDeviceEventReceived.send(payload);
  });
}

function installConnectionTrigger(deviceId) {
  let connection_trigger_payload = {
    name: `connectiontrigger-${deviceId}`,
    device_id: deviceId,
    simple_trigger: {
      type: "device_trigger",
      on: "device_connected",
      device_id: deviceId
    }
  };

  channel
    .push("watch", connection_trigger_payload)
    .receive("ok", resp => {
      app.ports.onDeviceEventReceived.send({
        message: "Device connection trigger installed",
        level: "info",
        timestamp: Date.now()
      });
    })
    .receive("error", resp => {
      app.ports.onDeviceEventReceived.send({
        message: "Failed to install the connection trigger",
        level: "error",
        timestamp: Date.now()
      });
    });
}

function installDisconnectionTrigger(deviceId) {
  let disconnection_trigger_payload = {
    name: `disconnectiontrigger-${deviceId}`,
    device_id: deviceId,
    simple_trigger: {
      type: "device_trigger",
      on: "device_disconnected",
      device_id: deviceId
    }
  };

  channel
    .push("watch", disconnection_trigger_payload)
    .receive("ok", resp => {
      app.ports.onDeviceEventReceived.send({
        message: "Device disconnection trigger installed",
        level: "info",
        timestamp: Date.now()
      });
    })
    .receive("error", resp => {
      app.ports.onDeviceEventReceived.send({
        message: "Failed to install the disconnection trigger",
        level: "error",
        timestamp: Date.now()
      });
    });
}

function installInterfaceTrigger(deviceId, name, major) {
  let data_trigger_payload = {
    name: `datatrigger-${name}-${deviceId}`,
    device_id: deviceId,
    simple_trigger: {
      type: "data_trigger",
      on: "incoming_data",
      interface_name: name,
      interface_major: major,
      value_match_operator: "*",
      match_path: "/*"
    }
  };

  channel
    .push("watch", data_trigger_payload)
    .receive("ok", resp => {
      app.ports.onDeviceEventReceived.send({
        message: "Data trigger for interface " + name + " installed",
        level: "info",
        timestamp: Date.now()
      });
    })
    .receive("error", resp => {
      app.ports.onDeviceEventReceived.send({
        message: "Failed to install data trigger for interface " + name,
        level: "error",
        timestamp: Date.now()
      });
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

  const reactApp = getRouter(reactHistory, noMatchFallback);
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
