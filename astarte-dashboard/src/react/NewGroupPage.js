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
  Accordion,
  Button,
  Form,
  InputGroup,
  OverlayTrigger,
  Table,
  Tooltip,
  Spinner
} from "react-bootstrap";

import AstarteClient from "./AstarteClient.js";
import Device from "./astarte/Device.js";
import SingleCardPage from "./ui/SingleCardPage.js";
import CheckableDeviceTable from "./ui/CheckableDeviceTable.js";
import { Link } from "react-router-dom";

export default class NewGroupPage extends React.Component {
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

    this.handleDevicesRequest = this.handleDevicesRequest.bind(this);
    this.handleDevicesError = this.handleDevicesError.bind(this);
    this.toggleDevice = this.toggleDevice.bind(this);
    this.updateGroupName = this.updateGroupName.bind(this);
    this.updateFilter = this.updateFilter.bind(this);
    this.createGroup = this.createGroup.bind(this);

    this.astarte = new AstarteClient(astarteConfig);
    this.astarte
      .getDevices(true)
      .then(this.handleDevicesRequest)
      .catch(this.handleDevicesError);
  }

  handleDevicesRequest(response) {
    let deviceList = response.data.map((value, index) => {
      return Device.fromObject(value);
    });

    this.setState({
      phase: "ok",
      devices: deviceList,
      selectedDevices: new Set(),
      deviceFilter: ""
    });
  }

  handleDevicesError(err) {
    this.setState({
      phase: "err",
      error: err
    });
  }

  toggleDevice(eventParams) {
    const senderItem = eventParams.target;
    const deviceId = senderItem.dataset.deviceId;
    let updatedSet = this.state.selectedDevices;

    if (senderItem.checked) {
      updatedSet.add(deviceId);
    } else {
      updatedSet.delete(deviceId);
    }

    this.setState({
      selectedDevices: updatedSet
    });
  }

  updateGroupName(e) {
    const name = e.target.value.trim();
    let feedback;
    let isValid;

    if (name.length == 0) {
      isValid = false;
      feedback = "The group name cannot be empty.";
    } else if (name.startsWith("@") || name.startsWith("~")) {
      isValid = false;
      feedback = "The group name cannot start with ~ or @";
    } else {
      isValid = true;
    }

    this.setState({
      groupName: name,
      validGroupName: isValid,
      markInvalid: !isValid,
      groupNameFeedback: feedback
    });
  }

  updateFilter(e) {
    this.setState({
      deviceFilter: e.target.value
    });
  }

  createGroup(e) {
    e.preventDefault();
    const { groupName, selectedDevices } = this.state;

    this.astarte
      .createGroup(groupName, Array.from(selectedDevices))
      .then(() => {
        this.props.history.push({ pathname: "/groups" });
      })
      .catch(() => {
        console.log(err);
      });
  }

  validInput(state) {
    const { validGroupName, selectedDevices } = state;
    return selectedDevices.size > 0 && validGroupName;
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        innerHTML = (
          <Form onSubmit={this.createGroup}>
            <Form.Group controlId="groupNameInput">
              <Form.Label>Group name</Form.Label>
              <Form.Control
                type="text"
                placeholder="Your group name"
                onChange={this.updateGroupName}
                autoComplete="off"
                required
                isValid={this.state.validGroupName}
                isInvalid={this.state.markInvalid}
              />
              <Form.Control.Feedback type="invalid">
                {this.state.groupNameFeedback}
              </Form.Control.Feedback>
            </Form.Group>
            <div className="table-toolbar p-1">
              <span>
                {deviceCountSentence(this.state.selectedDevices.size)}
              </span>
              <div className="float-right">
                <FilterInputBox
                  placeholder="Device ID/alias"
                  onChange={this.updateFilter}
                />
              </div>
            </div>
            <CheckableDeviceTable
              filter={this.state.deviceFilter}
              devices={this.state.devices}
              selectedDevices={this.state.selectedDevices}
              onToggleDevice={this.toggleDevice}
            />
            <Form.Row className="flex-row-reverse pr-2">
              <Button
                variant="primary"
                type="submit"
                disabled={!this.validInput(this.state)}
              >
                Create group
              </Button>
            </Form.Row>
          </Form>
        );
        break;

      case "err":
        innerHTML = <p>Couldn't load the device list</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return (
      <SingleCardPage title={`Create a New Group`}>{innerHTML}</SingleCardPage>
    );
  }
}

function FilterInputBox(props) {
  return (
    <Form.Group>
      <Form.Label srOnly>Table filter</Form.Label>
      <InputGroup>
        <InputGroup.Prepend>
          <InputGroup.Text>
            <i className="fas fa-filter"></i>
          </InputGroup.Text>
        </InputGroup.Prepend>
        <Form.Control
          type="text"
          placeholder={props.placeholder}
          onChange={props.onChange}
        />
      </InputGroup>
    </Form.Group>
  );
}

function deviceCountSentence(deviceCount) {
  if (deviceCount > 0) {
    return `${deviceCount} ${deviceCount == 1 ? "device" : "devices"} selected`;
  } else {
    return `Please select at least one device`;
  }
}
