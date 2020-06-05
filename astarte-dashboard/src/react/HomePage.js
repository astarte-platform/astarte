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
import { Link } from "react-router-dom";
import {
  Button,
  Col,
  Container,
  Card,
  Row,
  Spinner,
  Table
} from "react-bootstrap";

export default class HomePage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.updateDeviceStats = this.updateDeviceStats.bind(this);
    this.handleStatsError = this.handleStatsError.bind(this);
    this.updateInterfaceNames = this.updateInterfaceNames.bind(this);
    this.handleInterfaceError = this.handleInterfaceError.bind(this);
    this.updateTriggerNames = this.updateTriggerNames.bind(this);
    this.handleTriggerError = this.handleTriggerError.bind(this);
    this.redirectToLastInterface = this.redirectToLastInterface.bind(this);
    this.updateStatus = this.updateStatus.bind(this);

    const queryFlowHealth = this.astarte.config.enableFlowPreview;

    this.state = {
      connectedDevices: "loading",
      totalDevices: "loading",
      interfaces: "loading",
      triggers: "loading",
      appengineStatus: "loading",
      realmManagementStatus: "loading",
      pairingStatus: "loading",
      flowStatus: queryFlowHealth ? "loading" : null
    };

    this.astarte.getDevicesStats()
      .then(this.updateDeviceStats)
      .catch(this.handleStatsError);

    this.astarte.getInterfaceNames()
      .then(this.updateInterfaceNames)
      .catch(this.handleInterfaceError);

    this.astarte.getTriggerNames()
      .then(this.updateTriggerNames)
      .catch(this.handleTriggerError);

    this.astarte.getRealmManagementHealth()
      .then(() => { this.updateStatus("realmManagementStatus", "ok") })
      .catch(() => { this.updateStatus("realmManagementStatus", "err") });

    this.astarte.getAppengineHealth()
      .then(() => { this.updateStatus("appengineStatus", "ok") })
      .catch(() => { this.updateStatus("appengineStatus", "err") });

    this.astarte.getPairingHealth()
      .then(() => { this.updateStatus("pairingStatus", "ok") })
      .catch(() => { this.updateStatus("pairingStatus", "err") });

    if (queryFlowHealth) {
      this.astarte.getFlowHealth()
        .then(() => { this.updateStatus("flowStatus", "ok") })
        .catch(() => { this.updateStatus("flowStatus", "err") });
    }
  }

  updateDeviceStats(response) {
    this.setState({
      connectedDevices: response.data.connected_devices,
      totalDevices: response.data.total_devices
    });
  }

  handleStatsError(error) {
    this.setState({
      connectedDevices: "err",
      totalDevices: "err"
    });
  }

  updateInterfaceNames(response) {
    this.setState({
      interfaces: response.data
    });
  }

  updateTriggerNames(response) {
    this.setState({
      triggers: response.data
    });
  }

  handleInterfaceError(err) {
    console.log(err);
    this.setState({
      interfaces: "err"
    });
  }

  handleTriggerError(err) {
    console.log(err);
    this.setState({
      triggers: "err"
    });
  }

  updateStatus(service, status) {
    this.setState({
      [service]: status
    });
  }

  redirectToLastInterface(e, interfaceName) {
    e.preventDefault();

    const reactHistory = this.props.history;

    this.astarte.getInterfaceMajors(interfaceName)
      .then((response) => {
        const latestMajor = Math.max(...response.data);
        reactHistory.push(`/interfaces/${interfaceName}/${latestMajor}`);
      });
  }

  render() {
    const cellSpacingClass = "p-2";

    const {
      connectedDevices,
      totalDevices,
      appengineStatus,
      realmManagementStatus,
      pairingStatus,
      flowStatus,
      interfaces,
      triggers
    } = this.state;

    return (
      <Container fluid className="p-0">
        <Row noGutters>
          <Col xs={12} className={cellSpacingClass}>
            <WelcomeCard />
          </Col>
          <Col xs={6} className={cellSpacingClass}>
            <ApiStatusCard
              appengine={appengineStatus}
              realmManagement={realmManagementStatus}
              pairing={pairingStatus}
              flow={flowStatus}
            />
          </Col>
          { isReady(connectedDevices) &&
            <Col xs={6} className={cellSpacingClass}>
              <DevicesCard
                connectedDevices={connectedDevices}
                totalDevices={totalDevices}
              />
            </Col>
          }
          { isReady(interfaces) &&
            <Col xs={6} className={cellSpacingClass}>
              <InterfacesCard
                interfaceList={interfaces}
                onInterfaceClick={this.redirectToLastInterface}
                onInstallInterfaceClick={() => { this.props.history.push("/interfaces/new") }}
              />
            </Col>
          }
          { isReady(triggers) &&
            <Col xs={6} className={cellSpacingClass}>
              <TriggersCard
                triggerList={triggers}
                onInstallTriggerClick={() => { this.props.history.push("/triggers/new") }}
              />
            </Col>
          }
        </Row>
      </Container>
    );
  }
}

function WelcomeCard() {
  return (
    <Card>
      <Card.Body>
        <Card.Title as="h2">
          Welcome to Astarte Dashboard!
        </Card.Title>
        <Card.Text>
            Here you can easily manage your Astarte realm.
        </Card.Text>
        <Card.Text>
          Read the <a href="https://docs.astarte-platform.org/" target="_blank">documentation</a> for detailed information on Astarte.
        </Card.Text>
      </Card.Body>
    </Card>
  );
}

function ApiStatusCard(props) {
  const {
    appengine,
    realmManagement,
    pairing,
    flow
  } = props;

  return (
    <Card className="h-100">
      <Card.Header as="h5">
        API Status
      </Card.Header>
      <Card.Body>
        <Table responsive>
          <thead>
            <tr>
              <th>Service</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <ServiceStatusRow
              service="Realm Management"
              status={realmManagement}
            />
            <ServiceStatusRow
              service="AppEngine"
              status={appengine}
            />
            <ServiceStatusRow
              service="Pairing"
              status={pairing}
            />
            <ServiceStatusRow
              service="Flow"
              status={flow}
            />
          </tbody>
        </Table>
      </Card.Body>
    </Card>
  );
}

function DevicesCard({ connectedDevices, totalDevices }) {
  return (
    <Card className="h-100">
      <Card.Header as="h5">Devices</Card.Header>
      <Card.Body>
        <Card.Title>Connected devices</Card.Title>
        <Card.Text>{connectedDevices}</Card.Text>
        <Card.Title>Registered devices</Card.Title>
        <Card.Text>{totalDevices}</Card.Text>
      </Card.Body>
    </Card>
  );
}

function InterfacesCard({ interfaceList, onInterfaceClick, onInstallInterfaceClick }) {
  return (
    <Card className="h-100">
      <Card.Header as="h5">
        Interfaces
      </Card.Header>
      <Card.Body className="d-flex flex-column">
        { interfaceList.length > 0 ?
          <InterfaceList
            interfaces={interfaceList}
            onInterfaceClick={onInterfaceClick}
            maxShownInterfaces={4}
          />
        :
          <>
            <Card.Text>
              Interfaces defines how data is exchanged between Astarte and its peers.
            </Card.Text>
            <Card.Text>
              <a
                href="https://docs.astarte-platform.org/snapshot/030-interface.html"
                target="_blank"
              >
                Learn more...
              </a>
            </Card.Text>
          </>
        }
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
}

function TriggersCard({ triggerList, onInstallTriggerClick }) {
  return (
    <Card className="h-100">
      <Card.Header as="h5">
        Triggers
      </Card.Header>
      <Card.Body className="d-flex flex-column">
        { triggerList.length > 0 ? (
          <TriggerList
            triggers={triggerList}
            maxShownTriggers={4}
          />
        ) : (
          <>
            <Card.Text>
              Triggers in Astarte are the go-to mechanism for generating push events.</Card.Text>
            <Card.Text>
              Triggers allow users to specify conditions upon which a custom payload is delivered to a recipient,
              using a specific action, which usually maps to a specific transport/protocol, such as HTTP.
            </Card.Text>
            <Card.Text>
              <a
                href="https://docs.astarte-platform.org/snapshot/060-using_triggers.html"
                target="_blank"
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
}

function ServiceStatusRow({ service, status }) {
  if (!status) {
    return null;
  }

  let messageCell;

  if (status == "loading") {
    messageCell = (
      <td>
        <Spinner animation="border" role="status" />
      </td>
    );

  } else if (status == "ok") {
    messageCell = (
      <td className="color-green">
        <i className="fas fa-check-circle mr-1"></i>
        This service is operating normally
      </td>
    );

  } else {
    messageCell = (
      <td className="color-red">
        <i class="fas fa-times-circle mr-1"></i>
        This service appears offline
      </td>
    );
  }

  return (
    <tr>
      <td>{service}</td>
      { messageCell }
    </tr>
  );
}

function InterfaceList({ interfaces, onInterfaceClick, maxShownInterfaces }) {
  const shownInterfaces = interfaces.slice(0, maxShownInterfaces);
  const remainingInterfaces = interfaces.length - maxShownInterfaces;

  return (
    <ul className="list-unstyled">
      { shownInterfaces.map((interfaceName) =>
          <li
            key={interfaceName}
            className="my-1"
          >
            <a href="/interfaces"
              onClick={(e) => {onInterfaceClick(e, interfaceName)}}
            >
              <i className="fas fa-stream mr-1" />
              {interfaceName}
            </a>
          </li>)
      }
      { remainingInterfaces > 0 &&
        <li>
          <Link to="/interfaces">
            { remainingInterfaces } more installed { remainingInterfaces > 1 ? "interfaces" : "interface" }…
          </Link>
        </li>
      }
    </ul>
  );
}

function TriggerList({ triggers, maxShownTriggers }) {
  const shownTriggers = triggers.slice(0, maxShownTriggers);
  const remainingTriggers = triggers.length - maxShownTriggers;

  return (
    <ul className="list-unstyled">
      { shownTriggers.map((triggerName) =>
          <li
            key={triggerName}
            className="my-1"
          >
            <Link
              to={`/triggers/${triggerName}`}
            >
              <i className="fas fa-bolt mr-1" />
              {triggerName}
            </Link>
          </li>)
      }
      { remainingTriggers > 0 &&
        <li>
          <Link to="/triggers">
            { remainingTriggers } more installed { remainingTriggers > 1 ? "triggers" : "trigger" }…
          </Link>
        </li>
      }
    </ul>
  );
}

function isReady(value) {
  return (value != "loading" && value != "err");
}
