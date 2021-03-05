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
import { Navigate, Routes, Route, useParams, useLocation, useSearchParams } from 'react-router-dom';

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

function TriggerDetails(): React.ReactElement {
  const { triggerName } = useParams();
  return <TriggerPage triggerName={triggerName} />;
}

function InterfaceEdit(): React.ReactElement {
  const { interfaceName, interfaceMajor } = useParams();
  return (
    <InterfacePage interfaceName={interfaceName} interfaceMajor={parseInt(interfaceMajor, 10)} />
  );
}

function RegisterDevice(): React.ReactElement {
  const searchQuery = new URLSearchParams(useLocation().search);
  const deviceId = searchQuery.get('deviceId') || '';

  return <RegisterDevicePage deviceId={deviceId} />;
}

function GroupDevicesSubPath(): React.ReactElement {
  const { groupName } = useParams();
  const decodedGroupName = decodeURIComponent(groupName);

  return <GroupDevicesPage groupName={decodedGroupName} />;
}

function FlowDetails(): React.ReactElement {
  const { flowName } = useParams();

  return <FlowDetailsPage flowName={flowName} />;
}

function FlowConfiguration(): React.ReactElement {
  const [searchParams] = useSearchParams();
  const pipelineId = searchParams.get('pipelineId') || '';

  return <FlowConfigurationPage pipelineId={pipelineId} />;
}

function PipelineSubPath(): React.ReactElement {
  const { pipelineId } = useParams();

  return <PipelineSourcePage pipelineId={pipelineId} />;
}

function DeviceStatusSubPath(): React.ReactElement {
  const { deviceId } = useParams();

  return <DeviceStatusPage deviceId={deviceId} />;
}

function BlockSubPath(): React.ReactElement {
  const { blockId } = useParams();

  return <BlockSourcePage blockId={blockId} />;
}

function DeviceDataSubPath(): React.ReactElement {
  const { deviceId, interfaceName } = useParams();

  return <DeviceInterfaceValues deviceId={deviceId} interfaceName={interfaceName} />;
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
    <PrivateRoute path="triggers/:triggerName/edit" element={<TriggerDetails />} />
    <PrivateRoute path="interfaces" element={<InterfacesPage />} />
    <PrivateRoute path="interfaces/new" element={<NewInterfacePage />} />
    <PrivateRoute
      path="interfaces/:interfaceName/:interfaceMajor/edit"
      element={<InterfaceEdit />}
    />
    <PrivateRoute path="devices" element={<DevicesPage />} />
    <PrivateRoute path="devices/register" element={<RegisterDevice />} />
    <PrivateRoute path="devices/:deviceId/edit" element={<DeviceStatusSubPath />} />
    <PrivateRoute
      path="devices/:deviceId/interfaces/:interfaceName"
      element={<DeviceDataSubPath />}
    />
    <PrivateRoute path="groups" element={<GroupsPage />} />
    <PrivateRoute path="groups/new" element={<NewGroupPage />} />
    <PrivateRoute path="groups/:groupName/edit" element={<GroupDevicesSubPath />} />
    <PrivateRoute path="flows" element={<FlowInstancesPage />} />
    <PrivateRoute path="flows/new" element={<FlowConfiguration />} />
    <PrivateRoute path="flows/:flowName/edit" element={<FlowDetails />} />
    <PrivateRoute path="pipelines" element={<PipelinesPage />} />
    <PrivateRoute path="pipelines/new" element={<NewPipelinePage />} />
    <PrivateRoute path="pipelines/:pipelineId/edit" element={<PipelineSubPath />} />
    <PrivateRoute path="blocks" element={<BlocksPage />} />
    <PrivateRoute path="blocks/new" element={<NewBlockPage />} />
    <PrivateRoute path="blocks/:blockId/edit" element={<BlockSubPath />} />
    <PrivateRoute path="settings" element={<RealmSettingsPage />} />
    <Route path="*" element={<Navigate to="/" />} />
  </Routes>
);
