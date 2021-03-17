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

type ConfigContextValue = {
  auth: {
    methods: DashboardConfig['auth'];
    defaultMethod: 'oauth' | 'token';
    defaultRealm?: string;
  };
  features: {
    flow: boolean;
  };
};

const ConfigContext: React.Context<ConfigContextValue> = createContext(null) as any;

interface ConfigProviderProps {
  children: React.ReactNode;
  config: DashboardConfig;
}

const ConfigProvider = ({
  children,
  config,
  ...props
}: ConfigProviderProps): React.ReactElement => {
  const contextValue = useMemo(
    () => ({
      auth: {
        methods: config.auth,
        defaultMethod: config.defaultAuth || 'token',
        defaultRealm: config.defaultRealm,
      },
      features: {
        flow: !!config.enableFlowPreview,
      },
    }),
    [config],
  );

  return (
    <ConfigContext.Provider value={contextValue} {...props}>
      {children}
    </ConfigContext.Provider>
  );
};

const useConfig = (): ConfigContextValue => useContext(ConfigContext);

export { useConfig };

export default ConfigProvider;
