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
import { Redirect, Router, Switch, Route, useParams, useLocation } from 'react-router-dom';

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

export default ({ reactHistory, astarteClient, config, fallback, onSessionChange }) => {
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
        <Route path="/auth">
          <AttemptLogin
            appConfig={config}
            astarte={astarteClient}
            onSessionChange={onSessionChange}
          />
        </Route>
        <Route path="/logout">
          <Logout astarte={astarteClient} onSessionChange={onSessionChange} />
        </Route>
        <Route path="/login">
          <Login
            canSwitchLoginType={config.auth.length > 1}
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

function urlToSchemalessString(url) {
  return url.toString().split(/https?:\/\//)[1];
}

function AttemptLogin({ appConfig, astarte, onSessionChange }) {
  const { search, hash } = useLocation();
  const searchParams = new URLSearchParams(search);
  const hashParams = new URLSearchParams(hash.slice(1));

  if (!searchParams.has('realm') || !hashParams.has('access_token')) {
    if (localStorage.session && localStorage.session !== '') {
      return <Redirect to="/" />;
    }
    return <Redirect to="/login" />;
  }

  // base API URL
  const astarteApiUrl = appConfig.astarte_api_url;
  let appEngineApiUrl = '';
  let realmManagementApiUrl = '';
  let pairingApiUrl = '';
  let flowApiUrl = '';

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
  if (appConfig.appengine_api_url) {
    appEngineApiUrl = new URL(appConfig.appengine_api_url);
  }

  if (appConfig.realm_management_api_url) {
    realmManagementApiUrl = new URL(appConfig.realm_management_api_url);
  }

  if (appConfig.pairing_api_url) {
    pairingApiUrl = new URL(appConfig.pairing_api_url);
  }

  if (appConfig.flow_api_url) {
    flowApiUrl = new URL(appConfig.appConfig);
  }

  const realm = searchParams.get('realm');
  const token = hashParams.get('access_token');

  const apiConfig = {
    secure_connection: appEngineApiUrl.schema === 'https:',
    realm_management_url: urlToSchemalessString(realmManagementApiUrl),
    appengine_url: urlToSchemalessString(appEngineApiUrl),
    pairing_url: urlToSchemalessString(pairingApiUrl),
    enable_flow_preview: appConfig.enable_flow_preview,
    realm,
    token,
  };

  if (appConfig.enable_flow_preview) {
    apiConfig.flow_url = urlToSchemalessString(flowApiUrl);
  }

  const session = {
    api_config: apiConfig,
  };

  if (searchParams.has('authUrl')) {
    const authUrl = searchParams.get('authUrl');
    session.login_type = authUrl;
  } else {
    session.login_type = 'TokenLogin';
  }

  astarte.setCredentials({
    token,
    realm,
  });

  localStorage.session = JSON.stringify(session);
  onSessionChange(session);

  return <Redirect to="/" />;
}

function Logout({ astarte, onSessionChange }) {
  astarte.setCredentials({
    token: '',
    realm: '',
  });

  delete localStorage.session;
  onSessionChange(null);

  return <Redirect to="/login" />;
}

function Login({ defaultLoginType, ...props }) {
  const { search } = useLocation();
  const loginType = new URLSearchParams(search).get('type') || defaultLoginType;

  return <LoginPage type={loginType} {...props} />;
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
