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

import React, { useCallback, useEffect, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button, Col, Container, Card, Row, Spinner, Table } from 'react-bootstrap';
import { getConnectedDevices, ChartProvider, ConnectedDevices } from 'astarte-charts';
import { ConnectedDevicesChart } from 'astarte-charts/react';

import { useConfig } from './ConfigManager';
import { useAstarte } from './AstarteManager';
import useFetch from './hooks/useFetch';
import WaitForData from './components/WaitForData';

type ServiceStatus = 'loading' | 'ok' | 'err';

interface ServiceStatusRowProps {
  service: string;
  status: ServiceStatus;
}

const ServiceStatusRow = ({ service, status }: ServiceStatusRowProps): React.ReactElement => {
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
        <i className="fas fa-check-circle mr-1" />
        This service is operating normally
      </td>
    );
  } else {
    messageCell = (
      <td className="color-red">
        <i className="fas fa-times-circle mr-1" />
        This service appears offline
      </td>
    );
  }

  return (
    <tr>
      <td>{service}</td>
      {messageCell}
    </tr>
  );
};

interface ApiStatusCardProps {
  appengine: ServiceStatus;
  realmManagement: ServiceStatus;
  pairing: ServiceStatus;
  showFlowStatus: boolean;
  flow: ServiceStatus | null;
}

const ApiStatusCard = ({
  appengine,
  realmManagement,
  pairing,
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
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <ServiceStatusRow service="Realm Management" status={realmManagement} />
          <ServiceStatusRow service="AppEngine" status={appengine} />
          <ServiceStatusRow service="Pairing" status={pairing} />
          {showFlowStatus && flow && <ServiceStatusRow service="Flow" status={flow} />}
        </tbody>
      </Table>
    </Card.Body>
  </Card>
);

interface DevicesCardProps {
  connectedDevices: number;
  totalDevices: number;
  connectedDevicesProvider: ChartProvider<'Object', ConnectedDevices>;
}

const DevicesCard = ({
  connectedDevices,
  totalDevices,
  connectedDevicesProvider,
}: DevicesCardProps): React.ReactElement => (
  <Card id="devices-card" className="h-100">
    <Card.Header as="h5">Devices</Card.Header>
    <Card.Body>
      <Container className="h-100 p-0" fluid>
        <Row noGutters>
          <Col xs={12} lg={6}>
            <Card.Title>Connected devices</Card.Title>
            <Card.Text>{connectedDevices}</Card.Text>
            <Card.Title>Registered devices</Card.Title>
            <Card.Text>{totalDevices}</Card.Text>
          </Col>
          <Col xs={12} lg={6}>
            {totalDevices > 0 && <ConnectedDevicesChart provider={connectedDevicesProvider} />}
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

  return (
    <ul className="list-unstyled">
      {shownInterfaces.map((interfaceName) => (
        <li key={interfaceName} className="my-1">
          <a
            href="/interfaces"
            onClick={(e) => {
              onInterfaceClick(e, interfaceName);
            }}
          >
            <i className="fas fa-stream mr-1" />
            {interfaceName}
          </a>
        </li>
      ))}
      {remainingInterfaces > 0 && (
        <li>
          <Link to="/interfaces">
            {`${remainingInterfaces} more installed ${
              remainingInterfaces > 1 ? 'interfaces' : 'interface'
            }…`}
          </Link>
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
}: InterfacesCardProps): React.ReactElement => (
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
              href="https://docs.astarte-platform.org/snapshot/030-interface.html"
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
        onClick={onInstallInterfaceClick}
      >
        Install a new interface
      </Button>
    </Card.Body>
  </Card>
);

interface TriggerListProps {
  triggers: string[];
  maxShownTriggers: number;
}

const TriggerList = ({ triggers, maxShownTriggers }: TriggerListProps): React.ReactElement => {
  const shownTriggers = triggers.slice(0, maxShownTriggers);
  const remainingTriggers = triggers.length - maxShownTriggers;

  return (
    <ul className="list-unstyled">
      {shownTriggers.map((triggerName) => (
        <li key={triggerName} className="my-1">
          <Link to={`/triggers/${triggerName}/edit`}>
            <i className="fas fa-bolt mr-1" />
            {triggerName}
          </Link>
        </li>
      ))}
      {remainingTriggers > 0 && (
        <li>
          <Link to="/triggers">
            {`${remainingTriggers} more installed ${
              remainingTriggers > 1 ? 'triggers' : 'trigger'
            }…`}
          </Link>
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
}: TriggersCardProps): React.ReactElement => (
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
            Triggers allow users to specify conditions upon which a custom payload is delivered to a
            recipient, using a specific action, which usually maps to a specific transport/protocol,
            such as HTTP.
          </Card.Text>
          <Card.Text>
            <a
              href="https://docs.astarte-platform.org/snapshot/060-using_triggers.html"
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
        onClick={onInstallTriggerClick}
      >
        Install a new trigger
      </Button>
    </Card.Body>
  </Card>
);

export default (): React.ReactElement => {
  const astarte = useAstarte();
  const config = useConfig();
  const devicesStats = useFetch(astarte.client.getDevicesStats);
  const interfaces = useFetch(astarte.client.getInterfaceNames);
  const triggers = useFetch(astarte.client.getTriggerNames);
  const appEngineHealth = useFetch(astarte.client.getAppengineHealth);
  const realmManagementHealth = useFetch(astarte.client.getRealmManagementHealth);
  const pairingHealth = useFetch(astarte.client.getPairingHealth);
  const flowHealth = config.features.flow ? useFetch(astarte.client.getFlowHealth) : null;
  const navigate = useNavigate();

  const connectedDevicesProvider = useMemo(() => getConnectedDevices(astarte.client), [
    astarte.client,
  ]);

  const refreshData = () => {
    devicesStats.refresh();
    interfaces.refresh();
    triggers.refresh();
    appEngineHealth.refresh();
    realmManagementHealth.refresh();
    pairingHealth.refresh();
    if (config.features.flow && flowHealth) {
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

  const redirectToLastInterface = useCallback((e, interfaceName) => {
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
            realmManagement={realmManagementHealth.status}
            pairing={pairingHealth.status}
            showFlowStatus={config.features.flow}
            flow={flowHealth ? flowHealth.status : null}
          />
        </Col>
        <WaitForData data={devicesStats.value} status={devicesStats.status}>
          {({ connected_devices: connectedDevices, total_devices: totalDevices }) => (
            <Col xs={6} className={cellSpacingClass}>
              <DevicesCard
                connectedDevices={connectedDevices}
                totalDevices={totalDevices}
                connectedDevicesProvider={connectedDevicesProvider}
              />
            </Col>
          )}
        </WaitForData>
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
      </Row>
    </Container>
  );
};
