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
import type AstarteClient from 'astarte-client';

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
import { useSession } from './SessionManager';

interface PageProps {
  astarte: AstarteClient;
}

function AttemptLogin(): React.ReactElement {
  const { search, hash } = useLocation();
  const session = useSession();
  const searchParams = new URLSearchParams(search);
  const hashParams = new URLSearchParams(hash.slice(1));

  const realm = searchParams.get('realm');
  const token = hashParams.get('access_token');
  const authUrl = searchParams.get('authUrl');

  let succesfulLogin = false;

  if (realm && token) {
    succesfulLogin = session.manager.login({ realm, token, authUrl });
  }

  if (!succesfulLogin) {
    return <Navigate to="/login" />;
  }

  return <Navigate to="/" />;
}

function Logout(): React.ReactElement {
  const session = useSession();
  session.manager.logout();

  return <Navigate to="/login" />;
}

type LoginType = 'oauth' | 'token';

type LoginProps = PageProps & {
  canSwitchLoginType: boolean;
  defaultLoginType: LoginType;
  defaultRealm: string;
};

function Login({ defaultLoginType, ...props }: LoginProps): React.ReactElement {
  const { search } = useLocation();
  const session = useSession();

  if (session.isAuthenticated) {
    return <Navigate to="/" />;
  }

  const requestedLoginType = new URLSearchParams(search).get('type') || '';
  const loginType = ['oauth', 'token'].includes(requestedLoginType)
    ? (requestedLoginType as LoginType)
    : defaultLoginType;

  return <LoginPage type={loginType} {...props} />;
}

function TriggerDetails(props: PageProps): React.ReactElement {
  const { triggerName } = useParams();
  return <TriggerPage triggerName={triggerName} {...props} />;
}

function InterfaceEdit(props: PageProps): React.ReactElement {
  const { interfaceName, interfaceMajor } = useParams();
  return (
    <InterfacePage
      interfaceName={interfaceName}
      interfaceMajor={parseInt(interfaceMajor, 10)}
      {...props}
    />
  );
}

function RegisterDevice(props: PageProps): React.ReactElement {
  const searchQuery = new URLSearchParams(useLocation().search);
  const deviceId = searchQuery.get('deviceId') || '';

  return <RegisterDevicePage deviceId={deviceId} {...props} />;
}

function GroupDevicesSubPath(props: PageProps): React.ReactElement {
  const { groupName } = useParams();
  const decodedGroupName = decodeURIComponent(groupName);

  return <GroupDevicesPage groupName={decodedGroupName} {...props} />;
}

function FlowDetails(props: PageProps): React.ReactElement {
  const { flowName } = useParams();

  return <FlowDetailsPage flowName={flowName} {...props} />;
}

function FlowConfiguration(props: PageProps): React.ReactElement {
  const [searchParams] = useSearchParams();
  const pipelineId = searchParams.get('pipelineId') || '';

  return <FlowConfigurationPage pipelineId={pipelineId} {...props} />;
}

function PipelineSubPath(props: PageProps): React.ReactElement {
  const { pipelineId } = useParams();

  return <PipelineSourcePage pipelineId={pipelineId} {...props} />;
}

function DeviceStatusSubPath(props: PageProps): React.ReactElement {
  const { deviceId } = useParams();

  return <DeviceStatusPage deviceId={deviceId} {...props} />;
}

function BlockSubPath(props: PageProps): React.ReactElement {
  const { blockId } = useParams();

  return <BlockSourcePage blockId={blockId} {...props} />;
}

function DeviceDataSubPath(props: PageProps): React.ReactElement {
  const { deviceId, interfaceName } = useParams();

  return <DeviceInterfaceValues deviceId={deviceId} interfaceName={interfaceName} {...props} />;
}

type PrivateRouteProps = React.ComponentProps<typeof Route>;

const PrivateRoute = ({ ...props }: PrivateRouteProps) => {
  const session = useSession();
  return session.isAuthenticated ? <Route {...props} /> : <Navigate to="/login" />;
};

interface Props {
  astarte: AstarteClient;
  config: any;
}

export default ({ astarte, config }: Props): React.ReactElement => {
  const pageProps = {
    astarte,
  };

  return (
    <Routes>
      <PrivateRoute path="/" element={<HomePage {...pageProps} />} />
      <PrivateRoute path="home" element={<HomePage {...pageProps} />} />
      <Route path="auth" element={<AttemptLogin />} />
      <Route path="logout" element={<Logout />} />
      <Route
        path="login"
        element={
          <Login
            canSwitchLoginType={config.auth.length > 1}
            defaultLoginType={config.default_auth || 'token'}
            defaultRealm={config.default_realm || ''}
            {...pageProps}
          />
        }
      />
      <PrivateRoute path="triggers" element={<TriggersPage {...pageProps} />} />
      <PrivateRoute path="triggers/new" element={<NewTriggerPage {...pageProps} />} />
      <PrivateRoute path="triggers/:triggerName/edit" element={<TriggerDetails {...pageProps} />} />
      <PrivateRoute path="interfaces" element={<InterfacesPage {...pageProps} />} />
      <PrivateRoute path="interfaces/new" element={<NewInterfacePage {...pageProps} />} />
      <PrivateRoute
        path="interfaces/:interfaceName/:interfaceMajor/edit"
        element={<InterfaceEdit {...pageProps} />}
      />
      <PrivateRoute path="devices" element={<DevicesPage {...pageProps} />} />
      <PrivateRoute path="devices/register" element={<RegisterDevice {...pageProps} />} />
      <PrivateRoute
        path="devices/:deviceId/edit"
        element={<DeviceStatusSubPath {...pageProps} />}
      />
      <PrivateRoute
        path="devices/:deviceId/interfaces/:interfaceName"
        element={<DeviceDataSubPath {...pageProps} />}
      />
      <PrivateRoute path="groups" element={<GroupsPage {...pageProps} />} />
      <PrivateRoute path="groups/new" element={<NewGroupPage {...pageProps} />} />
      <PrivateRoute
        path="groups/:groupName/edit"
        element={<GroupDevicesSubPath {...pageProps} />}
      />
      <PrivateRoute path="flows" element={<FlowInstancesPage {...pageProps} />} />
      <PrivateRoute path="flows/new" element={<FlowConfiguration {...pageProps} />} />
      <PrivateRoute path="flows/:flowName/edit" element={<FlowDetails {...pageProps} />} />
      <PrivateRoute path="pipelines" element={<PipelinesPage {...pageProps} />} />
      <PrivateRoute path="pipelines/new" element={<NewPipelinePage {...pageProps} />} />
      <PrivateRoute
        path="pipelines/:pipelineId/edit"
        element={<PipelineSubPath {...pageProps} />}
      />
      <PrivateRoute path="blocks" element={<BlocksPage {...pageProps} />} />
      <PrivateRoute path="blocks/new" element={<NewBlockPage {...pageProps} />} />
      <PrivateRoute path="blocks/:blockId/edit" element={<BlockSubPath {...pageProps} />} />
      <PrivateRoute path="settings" element={<RealmSettingsPage {...pageProps} />} />
      <Route path="*" element={<Navigate to="/" />} />
    </Routes>
  );
};
