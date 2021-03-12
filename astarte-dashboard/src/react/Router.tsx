/*
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl

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
import { Navigate, Routes, Route, useLocation } from 'react-router-dom';

import LoginPage from './LoginPage';
import HomePage from './HomePage';
import GroupsPage from './GroupsPage';
import GroupDevicesPage from './GroupDevicesPage';
import NewGroupPage from './NewGroupPage';
import TriggersPage from './TriggersPage';
import NewTriggerPage from './NewTriggerPage';
import TriggerPage from './TriggerPage';
import InterfacesPage from './InterfacesPage';
import InterfacePage from './InterfacePage';
import NewInterfacePage from './NewInterfacePage';
import DevicesPage from './DevicesPage';
import RegisterDevicePage from './RegisterDevicePage';
import FlowInstancesPage from './FlowInstancesPage';
import FlowDetailsPage from './FlowDetailsPage';
import FlowConfigurationPage from './FlowConfigurationPage';
import PipelinesPage from './PipelinesPage';
import PipelineSourcePage from './PipelineSourcePage';
import NewPipelinePage from './NewPipelinePage';
import BlocksPage from './BlocksPage';
import BlockSourcePage from './BlockSourcePage';
import NewBlockPage from './NewBlockPage';
import RealmSettingsPage from './RealmSettingsPage';
import DeviceStatusPage from './DeviceStatusPage';
import DeviceInterfaceValues from './DeviceInterfaceValues';
import { useConfig } from './ConfigManager';
import { useAstarte } from './AstarteManager';

function AttemptLogin(): React.ReactElement {
  const { search, hash } = useLocation();
  const astarte = useAstarte();
  const searchParams = new URLSearchParams(search);
  const hashParams = new URLSearchParams(hash.slice(1));

  const realm = searchParams.get('realm');
  const token = hashParams.get('access_token');
  const authUrl = searchParams.get('authUrl');

  let succesfulLogin = false;

  if (realm && token) {
    succesfulLogin = astarte.login({ realm, token, authUrl });
  }

  if (!succesfulLogin) {
    return <Navigate to="/login" />;
  }

  return <Navigate to="/" />;
}

function Logout(): React.ReactElement {
  const astarte = useAstarte();
  astarte.logout();

  return <Navigate to="/login" />;
}

function Login(): React.ReactElement {
  const { search } = useLocation();
  const astarte = useAstarte();
  const config = useConfig();

  if (astarte.isAuthenticated) {
    return <Navigate to="/" />;
  }

  const requestedLoginType = new URLSearchParams(search).get('type') || '';
  const loginType = ['oauth', 'token'].includes(requestedLoginType)
    ? (requestedLoginType as 'oauth' | 'token')
    : config.auth.defaultMethod;

  return (
    <LoginPage
      type={loginType}
      canSwitchLoginType={config.auth.methods.length > 1}
      defaultRealm={config.auth.defaultRealm || ''}
    />
  );
}

type PrivateRouteProps = React.ComponentProps<typeof Route>;

const PrivateRoute = ({ ...props }: PrivateRouteProps) => {
  const astarte = useAstarte();
  return astarte.isAuthenticated ? <Route {...props} /> : <Navigate to="/login" />;
};

export default (): React.ReactElement => (
  <Routes>
    <PrivateRoute path="/" element={<HomePage />} />
    <PrivateRoute path="home" element={<HomePage />} />
    <Route path="auth" element={<AttemptLogin />} />
    <Route path="logout" element={<Logout />} />
    <Route path="login" element={<Login />} />
    <PrivateRoute path="triggers" element={<TriggersPage />} />
    <PrivateRoute path="triggers/new" element={<NewTriggerPage />} />
    <PrivateRoute path="triggers/:triggerName/edit" element={<TriggerPage />} />
    <PrivateRoute path="interfaces" element={<InterfacesPage />} />
    <PrivateRoute path="interfaces/new" element={<NewInterfacePage />} />
    <PrivateRoute
      path="interfaces/:interfaceName/:interfaceMajor/edit"
      element={<InterfacePage />}
    />
    <PrivateRoute path="devices" element={<DevicesPage />} />
    <PrivateRoute path="devices/register" element={<RegisterDevicePage />} />
    <PrivateRoute path="devices/:deviceId/edit" element={<DeviceStatusPage />} />
    <PrivateRoute
      path="devices/:deviceId/interfaces/:interfaceName"
      element={<DeviceInterfaceValues />}
    />
    <PrivateRoute path="groups" element={<GroupsPage />} />
    <PrivateRoute path="groups/new" element={<NewGroupPage />} />
    <PrivateRoute path="groups/:groupName/edit" element={<GroupDevicesPage />} />
    <PrivateRoute path="flows" element={<FlowInstancesPage />} />
    <PrivateRoute path="flows/new" element={<FlowConfigurationPage />} />
    <PrivateRoute path="flows/:flowName/edit" element={<FlowDetailsPage />} />
    <PrivateRoute path="pipelines" element={<PipelinesPage />} />
    <PrivateRoute path="pipelines/new" element={<NewPipelinePage />} />
    <PrivateRoute path="pipelines/:pipelineId/edit" element={<PipelineSourcePage />} />
    <PrivateRoute path="blocks" element={<BlocksPage />} />
    <PrivateRoute path="blocks/new" element={<NewBlockPage />} />
    <PrivateRoute path="blocks/:blockId/edit" element={<BlockSourcePage />} />
    <PrivateRoute path="settings" element={<RealmSettingsPage />} />
    <Route path="*" element={<Navigate to="/" />} />
  </Routes>
);
