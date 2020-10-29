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

import React, { useReducer, useLayoutEffect } from 'react';
import { Navigate, Router, Routes, Route, useParams, useLocation } from 'react-router-dom';

import LoginPage from './LoginPage';
import HomePage from './HomePage';
import GroupsPage from './GroupsPage';
import GroupDevicesPage from './GroupDevicesPage';
import NewGroupPage from './NewGroupPage';
import TriggersPage from './TriggersPage';
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

export default ({ reactHistory: history, astarteClient, sessionManager, config, fallback }) => {
  const [historyState, dispatchHistoryUpdate] = useReducer((_, action) => action, {
    action: history.action,
    location: history.location,
  });
  useLayoutEffect(() => history.listen(dispatchHistoryUpdate), [history]);

  const pageProps = {
    astarte: astarteClient,
  };

  return (
    <Router action={historyState.action} location={historyState.location} navigator={history}>
      <Routes>
        <Route path="/" element={<HomePage {...pageProps} />} />
        <Route path="home" element={<HomePage {...pageProps} />} />
        <Route path="auth" element={<AttemptLogin sessionManager={sessionManager} />} />
        <Route path="logout" element={<Logout sessionManager={sessionManager} />} />
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
        <Route path="triggers" element={<TriggersPage {...pageProps} />} />
        <Route path="interfaces" element={<InterfacesPage {...pageProps} />} />
        <Route path="interfaces/new" element={<NewInterfacePage {...pageProps} />} />
        <Route
          path="interfaces/:interfaceName/:interfaceMajor"
          element={<InterfaceEdit {...pageProps} />}
        />
        <Route path="devices" element={<DevicesPage {...pageProps} />} />
        <Route path="devices/register" element={<RegisterDevicePage {...pageProps} />} />
        <Route path="/devices/:deviceId" element={<DeviceStatusSubPath {...pageProps} />} />
        <Route
          path="devices/:deviceId/interfaces/:interfaceName"
          element={<DeviceDataSubPath {...pageProps} />}
        />
        <Route path="groups" element={<GroupsPage {...pageProps} />} />
        <Route path="groups/new" element={<NewGroupPage {...pageProps} />} />
        <Route path="groups/:groupName" element={<GroupDevicesSubPath {...pageProps} />} />
        <Route path="flows" element={<FlowInstancesPage {...pageProps} />} />
        <Route path="flows/new/:pipelineId" element={<FlowConfiguration {...pageProps} />} />
        <Route path="flows/:flowName" element={<FlowDetails {...pageProps} />} />
        <Route path="pipelines" element={<PipelinesPage {...pageProps} />} />
        <Route path="pipelines/new" element={<NewPipelinePage {...pageProps} />} />
        <Route path="pipelines/:pipelineId" element={<PipelineSubPath {...pageProps} />} />
        <Route path="blocks" element={<BlocksPage {...pageProps} />} />
        <Route path="blocks/new" element={<NewBlockPage {...pageProps} />} />
        <Route path="blocks/:blockId" element={<BlockSubPath {...pageProps} />} />
        <Route path="settings" element={<RealmSettingsPage {...pageProps} />} />
        <Route path="*" element={<NoMatch fallback={fallback} />} />
      </Routes>
    </Router>
  );
};

function AttemptLogin({ sessionManager }) {
  const { search, hash } = useLocation();
  const searchParams = new URLSearchParams(search);
  const hashParams = new URLSearchParams(hash.slice(1));

  const realm = searchParams.get('realm');
  const token = hashParams.get('access_token');
  const authUrl = searchParams.get('authUrl');

  const succesfulLogin = sessionManager.login(realm, token, authUrl);
  if (!succesfulLogin) {
    return <Navigate to="/login" />;
  }

  return <Navigate to="/" />;
}

function Logout({ sessionManager }) {
  sessionManager.logout();

  return <Navigate to="/login" />;
}

function Login({ defaultLoginType, ...props }) {
  const { search } = useLocation();
  const loginType = new URLSearchParams(search).get('type') || defaultLoginType;

  return <LoginPage type={loginType} {...props} />;
}

function InterfaceEdit(props) {
  const { interfaceName, interfaceMajor } = useParams();
  return (
    <InterfacePage
      interfaceName={interfaceName}
      interfaceMajor={parseInt(interfaceMajor, 10)}
      {...props}
    />
  );
}

function GroupDevicesSubPath(props) {
  const { groupName } = useParams();
  const decodedGroupName = decodeURIComponent(groupName);

  return <GroupDevicesPage groupName={decodedGroupName} {...props} />;
}

function FlowDetails(props) {
  const { flowName } = useParams();

  return <FlowDetailsPage flowName={flowName} {...props} />;
}

function FlowConfiguration(props) {
  const { pipelineId } = useParams();

  return <FlowConfigurationPage pipelineId={pipelineId} {...props} />;
}

function PipelineSubPath(props) {
  const { pipelineId } = useParams();

  return <PipelineSourcePage pipelineId={pipelineId} {...props} />;
}

function DeviceStatusSubPath(props) {
  const { deviceId } = useParams();

  return <DeviceStatusPage deviceId={deviceId} {...props} />;
}

function BlockSubPath(props) {
  const { blockId } = useParams();

  return <BlockSourcePage blockId={blockId} {...props} />;
}

function DeviceDataSubPath(props) {
  const { deviceId, interfaceName } = useParams();

  return <DeviceInterfaceValues deviceId={deviceId} interfaceName={interfaceName} {...props} />;
}

function NoMatch({ fallback }) {
  const pageLocation = useLocation();
  const relativeUrl = [pageLocation.pathname, pageLocation.search, pageLocation.hash].join('');
  fallback(relativeUrl);

  return <p>Redirecting...</p>;
}
