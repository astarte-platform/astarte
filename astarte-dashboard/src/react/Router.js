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

import React from "react";
import {
  Router,
  Switch,
  Route,
  Link,
  useParams,
  useLocation,
  useRouteMatch
} from "react-router-dom";

import LoginPage from "./LoginPage.js";
import HomePage from "./HomePage.js";
import GroupsPage from "./GroupsPage.js";
import GroupDevicesPage from "./GroupDevicesPage.js";
import NewGroupPage from "./NewGroupPage.js";
import TriggersPage from "./TriggersPage.js";
import InterfacesPage from "./InterfacesPage.js";
import DevicesPage from "./DevicesPage.js";
import RegisterDevicePage from "./RegisterDevicePage.js";
import FlowInstancesPage from "./FlowInstancesPage.js";
import FlowDetailsPage from "./FlowDetailsPage.js";
import FlowConfigurationPage from "./FlowConfigurationPage.js";
import PipelinesPage from "./PipelinesPage.js";
import PipelineSourcePage from "./PipelineSourcePage.js";
import NewPipelinePage from "./NewPipelinePage.js";
import RealmSettingsPage from "./RealmSettingsPage.js";
import DeviceInterfaceValues from "./DeviceInterfaceValues.js";

export function getRouter(reactHistory, astarteClient, config, fallback) {

  const pageProps = {
      history: reactHistory,
      astarte: astarteClient
  }

  return (
    <Router history={reactHistory}>
      <Switch>
        <Route exact path={["/", "/home"]}>
          <HomePage {...pageProps} />
        </Route>
        <Route path="/login">
          <Login
            allowSwitching={config.auth.length > 1}
            defaultLoginType={config.default_auth || "token"}
            defaultRealm={config.default_realm || ""}
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
        <Route exact path="/settings">
          <RealmSettingsPage {...pageProps} />
        </Route>
        <Route path="*">
          <NoMatch fallback={fallback} />
        </Route>
      </Switch>
    </Router>
  );
}

function Login(props) {
  const { search } = useLocation();
  const loginType = new URLSearchParams(search).get("type") || props.defaultLoginType;

  return (
    <LoginPage
      type={loginType}
      {...props}
    />
  );
}

function GroupDevicesSubPath(props) {
  let { groupName } = useParams();

  return <GroupDevicesPage groupName={groupName} {...props} />;
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

function NoMatch(props) {
  const pageLocation = useLocation()
  const relativeUrl = [pageLocation.pathname, pageLocation.search, pageLocation.hash].join('');
  props.fallback(relativeUrl);

  return <p>Redirecting...</p>;
}
