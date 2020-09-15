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

import React from 'react';
import {
  Router,
  Switch,
  Route,
  useParams,
  useLocation,
} from 'react-router-dom';

import LoginPage from './LoginPage';
import HomePage from './HomePage';
import GroupsPage from './GroupsPage';
import GroupDevicesPage from './GroupDevicesPage';
import NewGroupPage from './NewGroupPage';
import TriggersPage from './TriggersPage';
import InterfacesPage from './InterfacesPage';
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
import DeviceInterfaceValues from './DeviceInterfaceValues';

export default ({
  reactHistory, astarteClient, config, fallback,
}) => {
  const pageProps = {
    history: reactHistory,
    astarte: astarteClient,
  };

  return (
    <Router history={reactHistory}>
      <Switch>
        <Route exact path={['/', '/home']}>
          <HomePage {...pageProps} />
        </Route>
        <Route path="/login">
          <Login
            allowSwitching={config.auth.length > 1}
            defaultLoginType={config.default_auth || 'token'}
            defaultRealm={config.default_realm || ''}
            {...pageProps}
          />
        </Route>
        <Route exact path="/triggers">
          <TriggersPage {...pageProps} />
        </Route>
        <Route exact path="/interfaces">
          <InterfacesPage {...pageProps} />
        </Route>
        <Route exact path="/devices">
          <DevicesPage {...pageProps} />
        </Route>
        <Route exact path="/devices/register">
          <RegisterDevicePage {...pageProps} />
        </Route>
        <Route exact path="/devices/:deviceId/interfaces/:interfaceName">
          <DeviceDataSubPath {...pageProps} />
        </Route>
        <Route exact path="/groups">
          <GroupsPage {...pageProps} />
        </Route>
        <Route exact path="/groups/new">
          <NewGroupPage {...pageProps} />
        </Route>
        <Route path="/groups/:groupName">
          <GroupDevicesSubPath {...pageProps} />
        </Route>
        <Route exact path="/flows">
          <FlowInstancesPage {...pageProps} />
        </Route>
        <Route path="/flows/new/:pipelineId">
          <FlowConfiguration {...pageProps} />
        </Route>
        <Route path="/flows/:flowName">
          <FlowDetails {...pageProps} />
        </Route>
        <Route exact path="/pipelines">
          <PipelinesPage {...pageProps} />
        </Route>
        <Route exact path="/pipelines/new">
          <NewPipelinePage {...pageProps} />
        </Route>
        <Route exact path="/pipelines/:pipelineId">
          <PipelineSubPath {...pageProps} />
        </Route>
        <Route exact path="/blocks">
          <BlocksPage {...pageProps} />
        </Route>
        <Route exact path="/blocks/new">
          <NewBlockPage {...pageProps} />
        </Route>
        <Route exact path="/blocks/:blockId">
          <BlockSubPath {...pageProps} />
        </Route>
        <Route exact path="/settings">
          <RealmSettingsPage {...pageProps} />
        </Route>
        <Route path="*">
          <NoMatch fallback={fallback} />
        </Route>
      </Switch>
    </Router>
  );
};

function Login({ defaultLoginType, ...props }) {
  const { search } = useLocation();
  const loginType = new URLSearchParams(search).get('type') || defaultLoginType;

  return (
    <LoginPage
      type={loginType}
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

  return (
    <FlowConfigurationPage pipelineId={pipelineId} {...props} />
  );
}

function PipelineSubPath(props) {
  const { pipelineId } = useParams();

  return (
    <PipelineSourcePage pipelineId={pipelineId} {...props} />
  );
}

function BlockSubPath(props) {
  const { blockId } = useParams();

  return (
    <BlockSourcePage blockId={blockId} {...props} />
  );
}

function DeviceDataSubPath(props) {
  const { deviceId, interfaceName } = useParams();

  return (
    <DeviceInterfaceValues
      deviceId={deviceId}
      interfaceName={interfaceName}
      {...props}
    />
  );
}

function NoMatch({ fallback }) {
  const pageLocation = useLocation();
  const relativeUrl = [pageLocation.pathname, pageLocation.search, pageLocation.hash].join('');
  fallback(relativeUrl);

  return <p>Redirecting...</p>;
}
