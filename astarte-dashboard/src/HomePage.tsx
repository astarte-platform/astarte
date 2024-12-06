/*
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl
   Copyright 2022-2024 SECO Mind Srl

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

import React, { useCallback, useEffect, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button, Col, Container, Card, Row, Spinner, Table } from 'react-bootstrap';
import { getConnectedDevices, ChartProvider, ConnectedDevices } from 'astarte-charts';
import { ConnectedDevicesChart } from 'astarte-charts/react';

import { useConfig } from './ConfigManager';
import { useAstarte } from './AstarteManager';
import useFetch from './hooks/useFetch';
import Icon from './components/Icon';
import WaitForData from './components/WaitForData';

type ServiceStatus = 'loading' | 'ok' | 'err';

interface ServiceStatusRowProps {
  service: string;
  version?: string | null;
  status: ServiceStatus;
}

const ServiceStatusRow = ({
  service,
  version,
  status,
}: ServiceStatusRowProps): React.ReactElement => {
  let messageCell;

  if (status === 'loading') {
    messageCell = (
      <td>
        <Spinner animation="border" role="status" />
      </td>
    );
  } else if (status === 'ok') {
    messageCell = (
      <td className="color-green">
        <Icon icon="statusOK" className="me-1" />
        This service is operating normally
      </td>
    );
  } else {
    messageCell = (
      <td className="color-red">
        <Icon icon="statusKO" className="me-1" />
        This service appears offline
      </td>
    );
  }

  return (
    <tr>
      <td>{service}</td>
      <td>{version}</td>
      {messageCell}
    </tr>
  );
};

interface ApiStatusCardProps {
  appengine: ServiceStatus;
  appengineVersion: string | null;
  realmManagement: ServiceStatus;
  realmManagementVersion: string | null;
  pairing: ServiceStatus;
  pairingVersion: string | null;
  showFlowStatus: boolean;
  flow: ServiceStatus | null;
}

const ApiStatusCard = ({
  appengine,
  appengineVersion,
  realmManagement,
  realmManagementVersion,
  pairing,
  pairingVersion,
  showFlowStatus,
  flow,
}: ApiStatusCardProps): React.ReactElement => (
  <Card id="status-card" className="h-100">
    <Card.Header as="h5">API Status</Card.Header>
    <Card.Body>
      <Table responsive>
        <thead>
          <tr>
            <th>Service</th>
            <th>Version</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <ServiceStatusRow
            service="Realm Management"
            version={realmManagementVersion}
            status={realmManagement}
          />
          <ServiceStatusRow service="AppEngine" version={appengineVersion} status={appengine} />
          <ServiceStatusRow service="Pairing" version={pairingVersion} status={pairing} />
          {showFlowStatus && flow && <ServiceStatusRow service="Flow" status={flow} />}
        </tbody>
      </Table>
    </Card.Body>
  </Card>
);

interface DevicesCardProps {
  connectedDevices: number;
  totalDevices: number;
  deviceRegistrationLimit: number | null;
  connectedDevicesProvider: ChartProvider<'Object', ConnectedDevices>;
}

const DevicesCard = ({
  connectedDevices,
  totalDevices,
  deviceRegistrationLimit,
  connectedDevicesProvider,
}: DevicesCardProps): React.ReactElement => (
  <Card id="devices-card" className="h-100">
    <Card.Header as="h5">Devices</Card.Header>
    <Card.Body>
      <Container className="h-100 p-0" fluid>
        <Row noGutters>
          <Col xs={12} lg={6}>
            <Card.Title>Connected devices</Card.Title>
            <Card.Text>
              {connectedDevices} / {totalDevices}
            </Card.Text>
            <Card.Title>Registered devices</Card.Title>
            <Card.Text>
              {deviceRegistrationLimit != null
                ? `${totalDevices} / ${deviceRegistrationLimit}`
                : totalDevices}
            </Card.Text>
          </Col>
          <Col xs={12} lg={6}>
            <div style={{ maxHeight: '18em' }}>
              {totalDevices > 0 && <ConnectedDevicesChart provider={connectedDevicesProvider} />}
            </div>
          </Col>
        </Row>
      </Container>
    </Card.Body>
  </Card>
);

interface InterfaceListProps {
  interfaces: string[];
  onInterfaceClick: (
    event: React.MouseEvent<HTMLAnchorElement, MouseEvent>,
    interfaceName: string,
  ) => void;
  maxShownInterfaces: number;
}

const InterfaceList = ({
  interfaces,
  onInterfaceClick,
  maxShownInterfaces,
}: InterfaceListProps): React.ReactElement => {
  const shownInterfaces = interfaces.slice(0, maxShownInterfaces);
  const remainingInterfaces = interfaces.length - maxShownInterfaces;
  const astarte = useAstarte();

  return (
    <ul className="list-unstyled">
      {shownInterfaces.map((interfaceName) => (
        <li key={interfaceName} className="my-1">
          {astarte.token?.can('realmManagement', 'GET', `/interfaces/${interfaceName}`) ? (
            <a
              href="/interfaces"
              onClick={(e) => {
                onInterfaceClick(e, interfaceName);
              }}
            >
              <Icon icon="interfaces" className="me-1" />
              {interfaceName}
            </a>
          ) : (
            <>
              <Icon icon="interfaces" className="me-1" />
              {interfaceName}
            </>
          )}
        </li>
      ))}
      {remainingInterfaces > 0 && (
        <li>
          {astarte.token?.can('realmManagement', 'GET', `/interfaces`) ? (
            <Link to="/interfaces">
              {`${remainingInterfaces} more installed ${
                remainingInterfaces > 1 ? 'interfaces' : 'interface'
              }…`}
            </Link>
          ) : (
            <>
              {`${remainingInterfaces} more installed ${
                remainingInterfaces > 1 ? 'interfaces' : 'interface'
              }…`}
            </>
          )}
        </li>
      )}
    </ul>
  );
};

interface InterfacesCardProps {
  interfaceList: string[];
  onInterfaceClick: (
    event: React.MouseEvent<HTMLAnchorElement, MouseEvent>,
    interfaceName: string,
  ) => void;
  onInstallInterfaceClick: () => void;
}

const InterfacesCard = ({
  interfaceList,
  onInterfaceClick,
  onInstallInterfaceClick,
}: InterfacesCardProps): React.ReactElement => {
  const astarte = useAstarte();
  return (
    <Card id="interfaces-card" className="h-100">
      <Card.Header as="h5">Interfaces</Card.Header>
      <Card.Body className="d-flex flex-column">
        {interfaceList.length > 0 ? (
          <InterfaceList
            interfaces={interfaceList}
            onInterfaceClick={onInterfaceClick}
            maxShownInterfaces={4}
          />
        ) : (
          <>
            <Card.Text>
              Interfaces defines how data is exchanged between Astarte and its peers.
            </Card.Text>
            <Card.Text>
              <a
                href="https://docs.astarte-platform.org/1.2/030-interface.html"
                target="_blank"
                rel="noreferrer"
              >
                Learn more...
              </a>
            </Card.Text>
          </>
        )}
        <Button
          variant="primary"
          className="align-self-start mt-auto"
          hidden={!astarte.token?.can('realmManagement', 'POST', '/interfaces')}
          onClick={onInstallInterfaceClick}
        >
          Install a new interface
        </Button>
      </Card.Body>
    </Card>
  );
};

interface TriggerListProps {
  triggers: string[];
  maxShownTriggers: number;
}

const TriggerList = ({ triggers, maxShownTriggers }: TriggerListProps): React.ReactElement => {
  const shownTriggers = triggers.slice(0, maxShownTriggers);
  const remainingTriggers = triggers.length - maxShownTriggers;
  const astarte = useAstarte();

  return (
    <ul className="list-unstyled">
      {shownTriggers.map((triggerName) => (
        <li key={triggerName} className="my-1">
          {astarte.token?.can('realmManagement', 'GET', `/triggers/${triggerName}`) ? (
            <Link to={`/triggers/${triggerName}/edit`}>
              <Icon icon="triggers" className="me-1" />
              {triggerName}
            </Link>
          ) : (
            <>
              <Icon icon="triggers" className="me-1" />
              {triggerName}
            </>
          )}
        </li>
      ))}
      {remainingTriggers > 0 && (
        <li>
          {astarte.token?.can('realmManagement', 'GET', `/triggers`) ? (
            <Link to="/triggers">
              {`${remainingTriggers} more installed ${
                remainingTriggers > 1 ? 'triggers' : 'trigger'
              }…`}
            </Link>
          ) : (
            <>
              {`${remainingTriggers} more installed ${
                remainingTriggers > 1 ? 'triggers' : 'trigger'
              }…`}
            </>
          )}
        </li>
      )}
    </ul>
  );
};

interface TriggersCardProps {
  triggerList: string[];
  onInstallTriggerClick: () => void;
}

const TriggersCard = ({
  triggerList,
  onInstallTriggerClick,
}: TriggersCardProps): React.ReactElement => {
  const astarte = useAstarte();
  return (
    <Card id="triggers-card" className="h-100">
      <Card.Header as="h5">Triggers</Card.Header>
      <Card.Body className="d-flex flex-column">
        {triggerList.length > 0 ? (
          <TriggerList triggers={triggerList} maxShownTriggers={4} />
        ) : (
          <>
            <Card.Text>
              Triggers in Astarte are the go-to mechanism for generating push events.
            </Card.Text>
            <Card.Text>
              Triggers allow users to specify conditions upon which a custom payload is delivered to
              a recipient, using a specific action, which usually maps to a specific
              transport/protocol, such as HTTP.
            </Card.Text>
            <Card.Text>
              <a
                href="https://docs.astarte-platform.org/1.2/060-using_triggers.html"
                target="_blank"
                rel="noreferrer"
              >
                Learn more...
              </a>
            </Card.Text>
          </>
        )}
        <Button
          variant="primary"
          className="align-self-start mt-auto"
          hidden={!astarte.token?.can('realmManagement', 'POST', '/triggers')}
          onClick={onInstallTriggerClick}
        >
          Install a new trigger
        </Button>
      </Card.Body>
    </Card>
  );
};

const HomePage = (): React.ReactElement => {
  const astarte = useAstarte();
  const config = useConfig();
  const canFetchInterfaces = astarte.token?.can('realmManagement', 'GET', '/interfaces');
  const canFetchTriggers = astarte.token?.can('realmManagement', 'GET', '/triggers');
  const canFetchDeviceStats = astarte.token?.can('appEngine', 'GET', '/stats/devices');
  const canFetchDeviceRegistrationLimit = astarte.token?.can(
    'realmManagement',
    'GET',
    '/config/device_registration_limit',
  );
  const devicesStats = useFetch(
    canFetchDeviceStats
      ? astarte.client.getDevicesStats
      : async () => ({ connectedDevices: 0, totalDevices: 0 }),
  );
  const interfaces = useFetch(
    canFetchInterfaces ? astarte.client.getInterfaceNames : async () => [],
  );
  const triggers = useFetch(canFetchTriggers ? astarte.client.getTriggerNames : async () => []);
  const appEngineHealth = useFetch(astarte.client.getAppengineHealth);
  const appengineVersion = useFetch(astarte.client.getAppEngineVersion);
  const realmManagementHealth = useFetch(astarte.client.getRealmManagementHealth);
  const realmManagementVersion = useFetch(astarte.client.getRealmManagementVersion);
  const pairingHealth = useFetch(astarte.client.getPairingHealth);
  const pairingVersion = useFetch(astarte.client.getPairingVersion);
  const flowHealth = useFetch(config.features.flow ? astarte.client.getFlowHealth : async () => {});
  const deviceRegistrationLimitFetcher = useFetch(
    canFetchDeviceRegistrationLimit && canFetchDeviceStats
      ? astarte.client.getDeviceRegistrationLimit
      : async () => null,
  );
  const navigate = useNavigate();

  const connectedDevicesProvider = useMemo(
    () => getConnectedDevices(astarte.client),
    [astarte.client],
  );

  const refreshData = () => {
    if (canFetchDeviceStats) {
      devicesStats.refresh();
    }
    if (canFetchInterfaces) {
      interfaces.refresh();
    }
    if (canFetchTriggers) {
      triggers.refresh();
    }
    appEngineHealth.refresh();
    realmManagementHealth.refresh();
    pairingHealth.refresh();
    if (config.features.flow) {
      flowHealth.refresh();
    }
  };

  useEffect(() => {
    const refreshTimer = setInterval(() => {
      refreshData();
    }, 30000);

    return () => {
      clearTimeout(refreshTimer);
    };
  }, [astarte.client]);

  const redirectToLastInterface = useCallback((e: React.SyntheticEvent, interfaceName: string) => {
    e.preventDefault();
    astarte.client.getInterfaceMajors(interfaceName).then((interfaceMajors) => {
      const latestMajor = Math.max(...interfaceMajors);
      navigate(`/interfaces/${interfaceName}/${latestMajor}/edit`);
    });
  }, []);

  const cellSpacingClass = 'mb-3';

  return (
    <Container fluid className="p-3">
      <Row>
        <Col xs={12}>
          <h2 className="mb-4">Astarte Dashboard</h2>
        </Col>
        <Col xs={6} className={cellSpacingClass}>
          <ApiStatusCard
            appengine={appEngineHealth.status}
            appengineVersion={appengineVersion.value}
            realmManagement={realmManagementHealth.status}
            realmManagementVersion={realmManagementVersion.value}
            pairing={pairingHealth.status}
            pairingVersion={pairingVersion.value}
            showFlowStatus={config.features.flow}
            flow={config.features.flow ? flowHealth.status : null}
          />
        </Col>
        {canFetchDeviceStats && (
          <WaitForData data={devicesStats.value} status={devicesStats.status}>
            {({ connectedDevices, totalDevices }) => (
              <Col xs={6} className={cellSpacingClass}>
                <DevicesCard
                  connectedDevices={connectedDevices}
                  totalDevices={totalDevices}
                  deviceRegistrationLimit={deviceRegistrationLimitFetcher.value}
                  connectedDevicesProvider={connectedDevicesProvider}
                />
              </Col>
            )}
          </WaitForData>
        )}
        {canFetchInterfaces && (
          <WaitForData data={interfaces.value} status={interfaces.status}>
            {(interfaceList) => (
              <Col xs={6} className={cellSpacingClass}>
                <InterfacesCard
                  interfaceList={interfaceList}
                  onInterfaceClick={redirectToLastInterface}
                  onInstallInterfaceClick={() => navigate('/interfaces/new')}
                />
              </Col>
            )}
          </WaitForData>
        )}
        {canFetchTriggers && (
          <WaitForData data={triggers.value} status={triggers.status}>
            {(triggerList) => (
              <Col xs={6} className={cellSpacingClass}>
                <TriggersCard
                  triggerList={triggerList}
                  onInstallTriggerClick={() => navigate('/triggers/new')}
                />
              </Col>
            )}
          </WaitForData>
        )}
      </Row>
    </Container>
  );
};

export default HomePage;
