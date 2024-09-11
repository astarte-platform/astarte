/*
   This file is part of Astarte.

   Copyright 2020-2022 Ispirata Srl

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
import { Navigate, RouteObject, useLocation, useRoutes } from 'react-router-dom';

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
import TriggerPoliciesPage from './TriggerDeliveryPoliciesPage';
import NewPolicyPage from './NewTriggerDeliveryPolicyPage';
import TriggerDeliveryPolicyPage from './TriggerDeliveryPolicyPage';
import DeviceDataStreamValues from 'DeviceDataStreamValues';

function AttemptLogin(): React.ReactElement {
  const { search, hash } = useLocation();
  const astarte = useAstarte();
  const searchParams = new URLSearchParams(search);
  const hashParams = new URLSearchParams(hash.slice(1));

  const realm = searchParams.get('realm');
  const token = hashParams.get('access_token');
  const authUrl = searchParams.get('authUrl');
  const redirectTo = searchParams.get('redirectTo');

  const persistent = false;

  let succesfulLogin = false;

  if (realm && token) {
    succesfulLogin = astarte.login({ realm, token, authUrl }, persistent);
  }

  if (!succesfulLogin) {
    return <Navigate to="/login" replace />;
  }

  return redirectTo ? <Navigate to={redirectTo} replace /> : <Navigate to="/" replace />;
}

function Logout(): React.ReactElement {
  const astarte = useAstarte();
  astarte.logout();

  return <Navigate to="/login" replace />;
}

function Login(): React.ReactElement {
  const { search } = useLocation();
  const astarte = useAstarte();
  const config = useConfig();

  if (astarte.isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  const requestedLoginType = new URLSearchParams(search).get('type') || '';
  const loginType = ['oauth', 'token'].includes(requestedLoginType)
    ? (requestedLoginType as 'oauth' | 'token')
    : config.auth.defaultMethod;

  return (
    <LoginPage
      authOptions={config.auth.methods}
      defaultRealm={config.auth.defaultRealm || ''}
      defaultAuth={loginType}
    />
  );
}

const privateRoutes: RouteObject[] = [
  { path: '/', element: <HomePage /> },
  { path: 'home', element: <HomePage /> },
  { path: 'triggers', element: <TriggersPage /> },
  { path: 'triggers/new', element: <NewTriggerPage /> },
  { path: 'triggers/:triggerName/edit', element: <TriggerPage /> },
  { path: 'trigger-delivery-policies', element: <TriggerPoliciesPage /> },
  { path: 'trigger-delivery-policies/new', element: <NewPolicyPage /> },
  { path: 'trigger-delivery-policies/:policyName/edit', element: <TriggerDeliveryPolicyPage /> },
  { path: 'interfaces', element: <InterfacesPage /> },
  { path: 'interfaces/new', element: <NewInterfacePage /> },
  { path: 'interfaces/:interfaceName/:interfaceMajor/edit', element: <InterfacePage /> },
  { path: 'devices', element: <DevicesPage /> },
  { path: 'devices/register', element: <RegisterDevicePage /> },
  { path: 'devices/:deviceId/edit', element: <DeviceStatusPage /> },
  {
    path: 'devices/:deviceId/interfaces/:interfaceName/:interfaceMajor',
    element: <DeviceInterfaceValues />,
  },
  {
    path: 'devices/:deviceId/interfaces/:interfaceName/:interfaceMajor/datastream',
    element: <DeviceDataStreamValues />,
  },
  { path: 'groups', element: <GroupsPage /> },
  { path: 'groups/new', element: <NewGroupPage /> },
  { path: 'groups/:groupName/edit', element: <GroupDevicesPage /> },
  { path: 'flows', element: <FlowInstancesPage /> },
  { path: 'flows/new', element: <FlowConfigurationPage /> },
  { path: 'flows/:flowName/edit', element: <FlowDetailsPage /> },
  { path: 'pipelines', element: <PipelinesPage /> },
  { path: 'pipelines/new', element: <NewPipelinePage /> },
  { path: 'pipelines/:pipelineId/edit', element: <PipelineSourcePage /> },
  { path: 'blocks', element: <BlocksPage /> },
  { path: 'blocks/new', element: <NewBlockPage /> },
  { path: 'blocks/:blockId/edit', element: <BlockSourcePage /> },
  { path: 'settings', element: <RealmSettingsPage /> },
  { path: '*', element: <Navigate to="/" replace /> },
];

const publicRoutes: RouteObject[] = [
  { path: 'auth', element: <AttemptLogin /> },
  { path: 'logout', element: <Logout /> },
  { path: 'login', element: <Login /> },
];

export default (): React.ReactElement => {
  const astarte = useAstarte();
  const routes = astarte.isAuthenticated
    ? publicRoutes.concat(privateRoutes)
    : publicRoutes.concat({ path: '*', element: <Navigate to="/login" replace /> });
  const router = useRoutes(routes);
  return <>{router}</>;
};
