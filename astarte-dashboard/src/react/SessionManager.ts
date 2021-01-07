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

import { createNanoEvents, Emitter, Unsubscribe } from 'nanoevents';

type SessionManagerAuthParams =
  | {
      auth: [{ type: 'token' }];
      defaultAuth?: 'token';
      defaultRealm?: string;
    }
  | {
      auth: [{ type: 'oauth' }];
      defaultAuth?: 'oauth';
      defaultRealm?: string;
    }
  | {
      auth: [{ type: 'token' }, { type: 'oauth' }];
      defaultAuth?: 'token' | 'oauth';
      defaultRealm?: string;
    };

type SessionManagerParams = {
  astarteApiUrl: string;
  appEngineApiUrl?: string;
  realmManagementApiUrl?: string;
  pairingApiUrl?: string;
  flowApiUrl?: string;
  enableFlowPreview: boolean;
} & SessionManagerAuthParams;

type SessionConfig = {
  secureConnection: boolean;
  appEngineApiUrl: URL;
  realmManagementApiUrl: URL;
  pairingApiUrl: URL;
  flowApiUrl: URL;
  enableFlowPreview: boolean;
};

type SessionCredentials = {
  realm: string;
  token: string;
};

type Session = {
  config: SessionConfig;
  credentials: SessionCredentials;
  loginType: string | 'TokenLogin';
};

type SessionManagerEvents = {
  sessionChange: (session: Session | null) => void;
};

function urlToSchemalessString(url: URL): string {
  return url.toString().split(/https?:\/\//)[1];
}

function schemalessStringToURL(url: string, secureSchema: boolean): URL {
  return new URL(secureSchema ? `https://${url}` : `http://${url}`);
}

function serializeSession(session?: Session | null): string {
  if (!session) {
    return 'null';
  }
  return JSON.stringify({
    api_config: {
      secure_connection: !!session.config.secureConnection,
      realm_management_url: urlToSchemalessString(session.config.realmManagementApiUrl),
      appengine_url: urlToSchemalessString(session.config.appEngineApiUrl),
      pairing_url: urlToSchemalessString(session.config.pairingApiUrl),
      flow_url: urlToSchemalessString(session.config.flowApiUrl),
      enable_flow_preview: session.config.enableFlowPreview,
      realm: session.credentials.realm,
      token: session.credentials.token,
    },
    login_type: session.loginType,
  });
}

function deserializeSession(serializedSession?: string | null): Session | null {
  let session: Session | null = null;
  try {
    const json = JSON.parse(serializedSession || '');
    const secureConnection = !!json.api_config.secure_connection;
    session = {
      config: {
        secureConnection,
        realmManagementApiUrl: schemalessStringToURL(
          json.api_config.realm_management_url,
          secureConnection,
        ),
        appEngineApiUrl: schemalessStringToURL(json.api_config.appengine_url, secureConnection),
        pairingApiUrl: schemalessStringToURL(json.api_config.pairing_url, secureConnection),
        flowApiUrl: schemalessStringToURL(json.api_config.flow_url, secureConnection),
        enableFlowPreview: !!json.api_config.enable_flow_preview,
      },
      credentials: {
        realm: json.api_config.realm,
        token: json.api_config.token,
      },
      loginType: json.login_type,
    };
  } catch {
    session = null;
  }
  return session;
}

class SessionManager {
  #config: SessionConfig;

  #credentials: SessionCredentials | null;

  #authUrl: string | null;

  #storage = localStorage;

  #emitter: Emitter<SessionManagerEvents>;

  constructor(params: SessionManagerParams) {
    this.#emitter = createNanoEvents<SessionManagerEvents>();

    // base API URL
    const { astarteApiUrl } = params;
    let appEngineApiUrl: URL;
    let realmManagementApiUrl: URL;
    let pairingApiUrl: URL;
    let flowApiUrl: URL;

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
    if (params.appEngineApiUrl) {
      appEngineApiUrl = new URL(params.appEngineApiUrl);
    }

    if (params.realmManagementApiUrl) {
      realmManagementApiUrl = new URL(params.realmManagementApiUrl);
    }

    if (params.pairingApiUrl) {
      pairingApiUrl = new URL(params.pairingApiUrl);
    }

    if (params.flowApiUrl) {
      flowApiUrl = new URL(params.flowApiUrl);
    }

    this.#config = {
      secureConnection: appEngineApiUrl.protocol === 'https:',
      appEngineApiUrl,
      realmManagementApiUrl,
      pairingApiUrl,
      flowApiUrl,
      enableFlowPreview: !!params.enableFlowPreview,
    };

    this.#credentials = null;

    this.#authUrl = null;

    const previousSession = deserializeSession(this.#storage.getItem('session'));
    if (previousSession) {
      const { realm, token } = previousSession.credentials;
      const authUrl = previousSession.loginType !== 'TokenLogin' ? previousSession.loginType : null;
      this.login({ realm, token, authUrl });
    }
  }

  getConfig(): SessionConfig {
    return this.#config;
  }

  getCredentials(): SessionCredentials | null {
    return this.#credentials;
  }

  getLoginType(): 'oauth' | 'token' {
    return this.#authUrl ? 'oauth' : 'token';
  }

  getSession(): Session | null {
    if (this.#credentials == null) {
      return null;
    }
    return {
      config: this.#config,
      credentials: this.#credentials,
      loginType: this.#authUrl || 'TokenLogin',
    };
  }

  login(params: { realm: string; token: string; authUrl: string | null }): boolean {
    const { realm, token, authUrl } = params;

    if (!realm || !token) {
      return false;
    }

    this.#credentials = { realm, token };
    this.#authUrl = authUrl || null;

    const session = this.getSession();

    this.#storage.setItem('session', serializeSession(session));

    this.#emitter.emit('sessionChange', session);

    return true;
  }

  logout(): void {
    this.#storage.removeItem('session');
    this.#credentials = null;
    this.#authUrl = null;
    this.#emitter.emit('sessionChange', null);
  }

  on<Event extends keyof SessionManagerEvents>(
    event: Event,
    callback: SessionManagerEvents[Event],
  ): Unsubscribe {
    return this.#emitter.on(event, callback);
  }

  get isLoggedIn(): boolean {
    return this.#credentials != null;
  }

  // TODO: Remove this method once we won't need to pass session to Elm
  static serializeSession = serializeSession;
}

export default SessionManager;
