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

import ReactDOM from 'react-dom';
import { createBrowserHistory } from 'history';
import AstarteClient from 'astarte-client';

import getReactApp from '../react/App';
import SessionManager from '../react/SessionManager';

require('./styles/main.scss');

const $ = require('jquery');

// eslint-disable-next-line import/no-unresolved
const elmApp = require('../elm/Main').Elm.Main;

let reactHistory = null;
let dashboardConfig = null;
let app;
let astarteClient = null;
let sessionManager = null;

function noMatchFallback(url) {
  app.ports.onPageRequested.send(url);
}

function loadPage(page) {
  const elem = document.getElementById('react-page');
  if (elem) {
    reactHistory.push({ pathname: page.url });
    return;
  }

  const pageNode = document.getElementById('inner-page');

  if (!pageNode) {
    setTimeout(() => {
      loadPage(page);
    }, 100);
    return;
  }

  const node = document.createElement('div');
  node.id = 'react-page';
  pageNode.appendChild(node);

  reactHistory = createBrowserHistory();

  const reactApp = getReactApp(
    reactHistory,
    astarteClient,
    sessionManager,
    dashboardConfig,
    noMatchFallback,
  );
  ReactDOM.render(reactApp, document.getElementById('react-page'));
}

function clearReact() {
  const elem = document.getElementById('react-page');
  if (elem) {
    elem.remove();
  }
}

$.getJSON('/user-config/config.json', (result) => {
  dashboardConfig = result;
}).always(() => {
  sessionManager = new SessionManager(dashboardConfig);

  const parameters = {
    config: dashboardConfig,
    previousSession: JSON.stringify(sessionManager.getSession()),
  };

  // init app
  app = elmApp.init({ flags: parameters });

  const conf = sessionManager.getConfig();
  astarteClient = new AstarteClient({
    realmManagementUrl: conf.realmManagementApiUrl,
    appengineUrl: conf.appEngineApiUrl,
    pairingUrl: conf.pairingApiUrl,
    flowUrl: conf.flowApiUrl,
    enableFlowPreview: conf.enableFlowPreview,
  });

  if (sessionManager.isUserLoggedIn) {
    astarteClient.setCredentials(sessionManager.getCredentials());
  }

  // TODO use TargetEvent API or custom
  // events library
  sessionManager.onSessionChange = (newSession) => {
    app.ports.onSessionChange.send(newSession);

    astarteClient.setCredentials({
      token: newSession ? newSession.api_config.token : '',
      realm: newSession ? newSession.api_config.realm : '',
    });
  };

  /* begin Elm ports */
  app.ports.loadReactPage.subscribe(loadPage);
  app.ports.unloadReactPage.subscribe(clearReact);
  /* end Elm ports */
});
