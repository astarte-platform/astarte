/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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

import React, { createContext, useContext, useMemo } from 'react';

import type { DashboardConfig } from './types';

type LoginType = keyof AuthOptions;

interface TokenOptions {
  enabled: boolean;
}

interface OAuthOptions {
  enabled: boolean;
  oauthApiUrl?: string | null;
}

interface AuthOptions {
  token: TokenOptions;
  oauth: OAuthOptions;
}

type ConfigContextValue = {
  auth: {
    methods: AuthOptions;
    defaultMethod: LoginType;
    defaultRealm?: string;
  };
  features: {
    flow: boolean;
  };
};

const ConfigContext = createContext<ConfigContextValue | null>(null);

interface ConfigProviderProps {
  children: React.ReactNode;
  config: DashboardConfig;
}

const ConfigProvider = ({
  children,
  config,
  ...props
}: ConfigProviderProps): React.ReactElement => {
  const contextValue = useMemo(() => {
    const appConfig: ConfigContextValue = {
      auth: {
        methods: {
          token: {
            enabled: false,
          },
          oauth: {
            enabled: false,
            oauthApiUrl: null,
          },
        },
        defaultMethod: config.defaultAuth || 'token',
        defaultRealm: config.defaultRealm,
      },
      features: {
        flow: !!config.enableFlowPreview,
      },
    };

    config.auth.forEach((authOption) => {
      if (authOption.type === 'token') {
        appConfig.auth.methods.token.enabled = true;
      } else if (authOption.type === 'oauth') {
        appConfig.auth.methods.oauth.enabled = true;
        appConfig.auth.methods.oauth.oauthApiUrl = authOption.oauth_api_url || null;
      }
    });

    return appConfig;
  }, [config]);

  return (
    <ConfigContext.Provider value={contextValue} {...props}>
      {children}
    </ConfigContext.Provider>
  );
};

const useConfig = (): ConfigContextValue => {
  const contextValue = useContext(ConfigContext);
  if (contextValue == null) {
    throw new Error('ConfigContext has not been Provided');
  }
  return contextValue;
};

export { useConfig };

export type { AuthOptions, LoginType };

export default ConfigProvider;
