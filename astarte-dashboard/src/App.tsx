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

import React, { useCallback } from 'react';
import { BrowserRouter as RouterProvider } from 'react-router-dom';
import { Col, Container, Row } from 'react-bootstrap';

import AlertsProvider from './AlertManager';
import ConfigProvider, { useConfig } from './ConfigManager';
import InterfaceEditorPage from './InterfaceEditorPage';
import Sidebar from './Sidebar';
import PageRouter from './Router';
import AstarteProvider, { useAstarte } from './AstarteManager';
import type { DashboardConfig } from './types';
import Snackbar from './ui/Snackbar';
import useFetch from './hooks/useFetch';
import useInterval from './hooks/useInterval';

const DashboardSidebar = () => {
  const config = useConfig();
  const astarte = useAstarte();

  const healthFetcher = useFetch(() => {
    const apiChecks = [
      astarte.client.getAppengineHealth(),
      astarte.client.getRealmManagementHealth(),
      astarte.client.getPairingHealth(),
    ];
    if (config.features.flow) {
      apiChecks.push(astarte.client.getFlowHealth());
    }
    return Promise.all(apiChecks);
  });

  useInterval(healthFetcher.refresh, 30000);

  const isApiHealthy = healthFetcher.status !== 'err';

  if (!astarte.isAuthenticated) {
    return null;
  }

  return (
    <Col id="main-navbar" className="col-auto nav-col">
      <Sidebar>
        <Sidebar.Brand />
        <Sidebar.Item label="Home" link="/" icon="home" />
        <Sidebar.Separator />
        <Sidebar.Item label="Interfaces" link="/interfaces" icon="interfaces" />
        <Sidebar.Item label="Triggers" link="/triggers" icon="triggers" />
        <Sidebar.Separator />
        <Sidebar.Item label="Devices" link="/devices" icon="devices" />
        <Sidebar.Item label="Groups" link="/groups" icon="groups" />
        <Sidebar.Separator />
        {config.features.flow && (
          <>
            <Sidebar.Item label="Flows" link="/flows" icon="flows" />
            <Sidebar.Item label="Pipelines" link="/pipelines" icon="pipelines" />
            <Sidebar.Item label="Blocks" link="/blocks" icon="blocks" />
            <Sidebar.Separator />
          </>
        )}
        <Sidebar.Item label="Realm settings" link="/settings" icon="settings" />
        <Sidebar.Separator />
        <Sidebar.ApiStatus healthy={isApiHealthy} realm={astarte.realm} />
        <Sidebar.Separator />
        <Sidebar.Item label="Logout" link="/logout" icon="logout" />
        <Sidebar.AppInfo appVersion={process.env.REACT_APP_VERSION || ''} />
      </Sidebar>
    </Col>
  );
};

const Dashboard = () => (
  <Container fluid className="px-0">
    <Row className="no-gutters">
      <DashboardSidebar />
      <Col className="main-content vh-100 overflow-auto">
        <PageRouter />
      </Col>
    </Row>
  </Container>
);

const StandaloneEditor = () => (
  <Container fluid className="px-0">
    <Row className="no-gutters">
      <Col id="main-navbar" className="col-auto nav-col">
        <Sidebar>
          <Sidebar.Brand />
          <Sidebar.Item label="Interface Editor" link="/" icon="interfaces" />
        </Sidebar>
      </Col>
      <Col className="main-content vh-100 overflow-auto">
        <InterfaceEditorPage />
      </Col>
    </Row>
  </Container>
);

interface Props {
  config: DashboardConfig | null;
}

export default ({ config }: Props): React.ReactElement => (
  <AlertsProvider>
    <RouterProvider>
      {config ? (
        <ConfigProvider config={config}>
          <AstarteProvider config={config}>
            <Dashboard />
          </AstarteProvider>
        </ConfigProvider>
      ) : (
        <StandaloneEditor />
      )}
    </RouterProvider>
    <Snackbar />
  </AlertsProvider>
);
