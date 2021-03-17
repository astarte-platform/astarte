/*
   This file is part of Astarte.

   Copyright 2017-2021 Ispirata Srl

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

import React from 'react';
import ReactDOM from 'react-dom';

import './styles/main.scss';
import App from './App';
import type { DashboardConfig } from './types';

fetch('/user-config/config.json')
  .then((response) => response.json())
  .then((json) => ({
    astarteApiUrl: json.astarte_api_url,
    appEngineApiUrl: json.appengine_api_url,
    realmManagementApiUrl: json.realm_management_api_url,
    pairingApiUrl: json.pairing_api_url,
    flowApiUrl: json.flow_api_url,
    enableFlowPreview: json.enable_flow_preview,
    auth: json.auth,
    defaultAuth: json.default_auth,
    defaultRealm: json.default_realm,
  }))
  .catch(() => null)
  .then((config: DashboardConfig | null) => {
    ReactDOM.render(
      <React.StrictMode>
        <App config={config} />
      </React.StrictMode>,
      document.getElementById('root'),
    );
  });
