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
  Button,
  Modal,
  OverlayTrigger,
  Spinner,
  Table,
  Tooltip
} from "react-bootstrap";

import AstarteClient from "./AstarteClient.js";
import Device from "./astarte/Device.js";
import SingleCardPage from "./ui/SingleCardPage.js";
import { Link } from "react-router-dom";

export default class GroupDevicesPage extends React.Component {
  constructor(props) {
    super(props);

    let config = JSON.parse(localStorage.session).api_config;
    let protocol = config.secure_connection ? "https://" : "http://";
    let astarteConfig = {
      realm: config.realm,
      token: config.token,
      realmManagementUrl: protocol + config.realm_management_url,
      appengineUrl: protocol + config.appengine_url
    };
    this.astarte = new AstarteClient(astarteConfig);

    this.loadGroups = this.loadGroups.bind(this);
    this.handleDeviesRequest = this.handleDeviesRequest.bind(this);
    this.handleDevicesError = this.handleDevicesError.bind(this);
    this.showModal = this.showModal.bind(this);
    this.handleModalCancel = this.handleModalCancel.bind(this);
    this.removeDevice = this.removeDevice.bind(this);

    this.loadGroups();
  }

  loadGroups() {
    this.state = {
      phase: "loading",
      showModal: false
    };

    this.astarte
      .getDevicesInGroup({
        groupName: this.props.groupName,
        details: true
      })
      .then(this.handleDeviesRequest)
      .catch(this.handleDevicesError);
  }

  handleDeviesRequest(response) {
    let deviceList = response.data.map((value, index) => {
      return Device.fromObject(value);
    });

    this.setState({
      phase: "ok",
      devices: deviceList
    });
  }

  handleDevicesError(err) {
    this.setState({
      phase: "err",
      error: err
    });
  }

  showModal(device) {
    this.setState({
      showModal: true,
      selectedDeviceName: device.name,
      selectedDeviceId: device.id
    });
  }

  handleModalCancel() {
    this.setState({
      showModal: false
    });
  }

  removeDevice() {
    this.setState({
      removingDevice: true
    });

    this.astarte
      .removeDeviceFromGroup({
        groupName: this.props.groupName,
        deviceId: this.state.selectedDeviceId
      })
      .finally(() => {
        if (this.state.devices?.length == 1) {
          this.props.history.push({ pathname: "/groups" });
        } else {
          this.setState({
            removingDevice: false,
            showModal: false
          });
          this.loadGroups();
        }
      });
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        innerHTML = deviceTable(this.state.devices, this.showModal);
        break;

      case "err":
        innerHTML = <p>Couldn't load devices in group</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return (
      <SingleCardPage title={`Devices in Group "${this.props.groupName}"`}>
        {innerHTML}
        <Modal
          size="lg"
          show={this.state.showModal}
          onHide={this.handleModalCancel}
        >
          <Modal.Header closeButton>
            <Modal.Title>Warning</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            {this.state.devices?.length == 1 ? (
              <p>
                This is the last device in the group. Removing this device will
                delete the group
              </p>
            ) : null}
            <p>{`Remove device "${this.state.selectedDeviceName}" from group "${this.props.groupName}"?`}</p>
          </Modal.Body>
          <Modal.Footer>
            <Button variant="secondary" onClick={this.handleModalCancel}>
              Cancel
            </Button>
            <Button variant="danger" onClick={this.removeDevice}>
              <>
                {this.state.removingDevice ? (
                  <Spinner
                    className="mr-1"
                    size="sm"
                    animation="border"
                    role="status"
                  />
                ) : null}
                Remove
              </>
            </Button>
          </Modal.Footer>
        </Modal>
      </SingleCardPage>
    );
  }
}

function deviceTable(deviceList, showModal) {
  return (
    <Table responsive>
      <thead>
        <tr>
          <th>Status</th>
          <th>Device ID</th>
          <th>Last connection event</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {deviceList.map((device, index) =>
          deviceTableRow(device, index, showModal)
        )}
      </tbody>
    </Table>
  );
}

function deviceTableRow(device, index, showModal) {
  let colorClass;
  let lastEvent;
  let tooltipText;

  if (device.connected) {
    tooltipText = "Connected";
    colorClass = "icon-connected";
    lastEvent = `Connected at ${device.lastConnection.toLocaleString()}`;
  } else if (device.lastConnection) {
    tooltipText = "Disconnected";
    colorClass = "icon-disconnected";
    lastEvent = `Disconnected at ${device.lastDisconnection.toLocaleString()}`;
  } else {
    tooltipText = "Never connected";
    colorClass = "icon-never-connected";
    lastEvent = `Never connected`;
  }

  return (
    <tr key={index}>
      <td>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 400 }}
          style={{
            backgroundColor: "rgba(255, 100, 100, 0.85)",
            padding: "2px 10px",
            color: "white",
            borderRadius: 3
          }}
          overlay={<Tooltip>{tooltipText}</Tooltip>}
        >
          <CircleIcon className={colorClass} />
        </OverlayTrigger>
      </td>
      <td>
        <Link to={`/devices/${device.id}`}>{device.name}</Link>
      </td>
      <td>{lastEvent}</td>
      <td>
        <OverlayTrigger
          placement="left"
          delay={{ show: 150, hide: 400 }}
          style={{
            backgroundColor: "rgba(255, 100, 100, 0.85)",
            padding: "2px 10px",
            color: "white",
            borderRadius: 3
          }}
          overlay={<Tooltip>Remove from group</Tooltip>}
        >
          <Button
            as="i"
            variant="danger"
            className="fas fa-times"
            onClick={() => showModal(device)}
          ></Button>
        </OverlayTrigger>
      </td>
    </tr>
  );
}

const CircleIcon = React.forwardRef((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));
