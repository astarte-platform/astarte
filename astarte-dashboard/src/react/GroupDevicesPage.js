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
import OverlayTrigger from "react-bootstrap/OverlayTrigger";
import Table from "react-bootstrap/Table";
import Tooltip from "react-bootstrap/Tooltip";
import Spinner from "react-bootstrap/Spinner";

import AstarteClient from "./AstarteClient.js";
import Device from "./astarte/Device.js";
import Card from "./ui/Card.js";
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

    this.state = {
      phase: "loading"
    };

    this.handleDeviesRequest = this.handleDeviesRequest.bind(this);
    this.handleDevicesError = this.handleDevicesError.bind(this);

    let astarte = new AstarteClient(astarteConfig);
    astarte
      .getDevicesInGroup(props.groupName, true)
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

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        innerHTML = deviceTable(this.state.devices);
        break;

      case "err":
        innerHTML = <p>Couldn't load devices in group</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return (
      <Card title={`Devices in group "${this.props.groupName}"`}>
        {innerHTML}
      </Card>
    );
  }
}

function deviceTable(deviceList) {
  return (
    <Table responsive>
      <thead>
        <tr>
          <th>Status</th>
          <th>Device ID</th>
          <th>Last connection event</th>
        </tr>
      </thead>
      <tbody>{deviceList.map(deviceTableRow)}</tbody>
    </Table>
  );
}

function deviceTableRow(device, index) {
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
    </tr>
  );
}

const CircleIcon = React.forwardRef((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));
