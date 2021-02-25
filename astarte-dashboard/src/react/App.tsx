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

import React, { useEffect, useMemo } from 'react';
import { BrowserRouter as RouterProvider } from 'react-router-dom';
import { Col, Container, Row } from 'react-bootstrap';
import AstarteClient from 'astarte-client';

import AlertsProvider from './AlertManager';
import InterfaceEditorPage from './InterfaceEditorPage';
import Sidebar from './Sidebar';
import PageRouter from './Router';
import SessionProvider, { useSession } from './SessionManager';
import type { DashboardConfig } from './types';
import Snackbar from './ui/Snackbar';

interface DashboardProps {
  config: DashboardConfig;
}

const Dashboard = ({ config }: DashboardProps) => {
  const session = useSession();

  const astarte = useMemo(() => {
    const conf = session.manager.getConfig();
    const astarteClient = new AstarteClient({
      realmManagementUrl: conf.realmManagementApiUrl.toString(),
      appengineUrl: conf.appEngineApiUrl.toString(),
      pairingUrl: conf.pairingApiUrl.toString(),
      flowUrl: conf.flowApiUrl.toString(),
      enableFlowPreview: conf.enableFlowPreview,
    });
    astarteClient.setCredentials(session.manager.getCredentials());
    return astarteClient;
  }, [session.manager]);

  useEffect(() => {
    astarte.setCredentials(session.credentials);
  }, [session.credentials, astarte]);

  return (
    <Container fluid className="px-0">
      <Row className="no-gutters">
        {session.isAuthenticated && (
          <Col id="main-navbar" className="col-auto nav-col">
            <Sidebar>
              <Sidebar.Brand />
              <Sidebar.Item label="Home" link="/" icon="home" />
              <Sidebar.Separator />
              <Sidebar.Item label="Interfaces" link="/interfaces" icon="stream" />
              <Sidebar.Item label="Triggers" link="/triggers" icon="bolt" />
              <Sidebar.Separator />
              <Sidebar.Item label="Devices" link="/devices" icon="cube" />
              <Sidebar.Item label="Groups" link="/groups" icon="object-group" />
              <Sidebar.Separator />
              {astarte.features.flow && (
                <>
                  <Sidebar.Item label="Flows" link="/flows" icon="wind" />
                  <Sidebar.Item label="Pipelines" link="/pipelines" icon="code-branch" />
                  <Sidebar.Item label="Blocks" link="/blocks" icon="shapes" />
                  <Sidebar.Separator />
                </>
              )}
              <Sidebar.Item label="Realm settings" link="/settings" icon="cog" />
              <Sidebar.Separator />
              <Sidebar.ApiStatus astarte={astarte} />
              <Sidebar.Separator />
              <Sidebar.Item label="Logout" link="/logout" icon="sign-out-alt" />
            </Sidebar>
          </Col>
        )}
        <Col className="main-content vh-100 overflow-auto">
          <PageRouter astarte={astarte} config={config} />
        </Col>
      </Row>
    </Container>
  );
};

const StandaloneEditor = () => (
  <Container fluid className="px-0">
    <Row className="no-gutters">
      <Col id="main-navbar" className="col-auto nav-col">
        <Sidebar>
          <Sidebar.Brand />
          <Sidebar.Item label="Interface Editor" link="/" icon="stream" />
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
        <SessionProvider config={config}>
          <Dashboard config={config} />
        </SessionProvider>
      ) : (
        <StandaloneEditor />
      )}
    </RouterProvider>
    <Snackbar />
  </AlertsProvider>
);
