/*
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

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

function urlToSchemalessString(url) {
  return url.toString().split(/https?:\/\//)[1];
}

class SessionManager {
  constructor(appConfig) {
    // base API URL
    const astarteApiUrl = appConfig.astarte_api_url;
    let appEngineApiUrl = '';
    let realmManagementApiUrl = '';
    let pairingApiUrl = '';
    let flowApiUrl = '';

    if (astarteApiUrl === 'localhost') {
      appEngineApiUrl = new URL('http://localhost:4002');
      realmManagementApiUrl = new URL('http://localhost:4000');
      pairingApiUrl = new URL('http://localhost:4003');
      flowApiUrl = new URL('http://localhost:4009');
    } else {
      appEngineApiUrl = new URL('appengine/', astarteApiUrl);
      realmManagementApiUrl = new URL('realmmanagement/', astarteApiUrl);
      pairingApiUrl = new URL('pairing/', astarteApiUrl);
      flowApiUrl = new URL('flow/', astarteApiUrl);
    }

    // API URL overwrite
    if (appConfig.appengine_api_url) {
      appEngineApiUrl = new URL(appConfig.appengine_api_url);
    }

    if (appConfig.realm_management_api_url) {
      realmManagementApiUrl = new URL(appConfig.realm_management_api_url);
    }

    if (appConfig.pairing_api_url) {
      pairingApiUrl = new URL(appConfig.pairing_api_url);
    }

    if (appConfig.flow_api_url) {
      flowApiUrl = new URL(appConfig.flow_api_url);
    }

    this.config = {
      enableFlowPreview: !!appConfig.enable_flow_preview,
      appEngineApiUrl,
      realmManagementApiUrl,
      pairingApiUrl,
      flowApiUrl,
    };

    // initial session
    let previousSession;

    try {
      previousSession = JSON.parse(localStorage.session);
    } catch (err) {
      previousSession = null;
    }

    if (previousSession) {
      const { realm, token } = previousSession.api_config;
      const authUrl =
        previousSession.login_type !== 'TokenLogin' ? previousSession.login_type : null;
      this.login(realm, token, authUrl);
    } else {
      this.isLoggedIn = false;
      this.credentials = null;
      this.authUrl = null;
    }
  }

  getConfig() {
    return this.config;
  }

  getCredentials() {
    return this.credentials;
  }

  getLoginType() {
    return this.authUrl ? 'OAuth' : 'Token';
  }

  getSession() {
    if (!this.isLoggedIn) {
      return null;
    }

    const { enableFlowPreview, appEngineApiUrl, realmManagementApiUrl, pairingApiUrl, flowApiUrl } =
      this.config;

    const { realm, token } = this.credentials;

    const apiConfig = {
      secure_connection: appEngineApiUrl.protocol === 'https:',
      realm_management_url: urlToSchemalessString(realmManagementApiUrl),
      appengine_url: urlToSchemalessString(appEngineApiUrl),
      pairing_url: urlToSchemalessString(pairingApiUrl),
      flow_url: urlToSchemalessString(flowApiUrl),
      enable_flow_preview: enableFlowPreview,
      realm,
      token,
    };

    return {
      api_config: apiConfig,
      login_type: this.authUrl || 'TokenLogin',
    };
  }

  get isUserLoggedIn() {
    return this.isLoggedIn;
  }

  login(realm, token, authUrl) {
    if (!realm || !token) {
      return false;
    }

    this.credentials = { realm, token };
    this.authUrl = authUrl || null;
    this.isLoggedIn = true;

    const session = this.getSession();

    localStorage.session = JSON.stringify(session);
    if (this.onSessionChange) {
      this.onSessionChange(session);
    }

    return true;
  }

  logout() {
    delete localStorage.session;
    this.isLoggedIn = false;
    this.loginType = null;
    this.authUrl = null;

    if (this.onSessionChange) {
      this.onSessionChange(null);
    }
  }
}

export default SessionManager;
