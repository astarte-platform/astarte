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
import { Button, Spinner, Table } from "react-bootstrap";

import AstarteClient from "./AstarteClient.js";
import Device from "./astarte/Device.js";
import SingleCardPage from "./ui/SingleCardPage.js";

export default class GroupsPage extends React.Component {
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

    this.handleGroupsRequest = this.handleGroupsRequest.bind(this);
    this.handleGroupsError = this.handleGroupsError.bind(this);
    this.handleDeviceList = this.handleDeviceList.bind(this);
    this.handleDeviceError = this.handleDeviceError.bind(this);
    this.goNewGroupPage = this.goNewGroupPage.bind(this);

    this.astarte = new AstarteClient(astarteConfig);
    this.astarte
      .getGroupList()
      .then(this.handleGroupsRequest)
      .catch(this.handleGroupsError);
  }

  handleGroupsRequest(response) {
    let groupMap = response.data.reduce((acc, groupName) => {
      acc.set(groupName, { name: groupName, loading: true });
      return acc;
    }, new Map());

    for (let groupName of groupMap.keys()) {
      this.astarte
        .getDevicesInGroup({
          groupName: groupName,
          details: true
        })
        .then(response => this.handleDeviceList(groupName, response))
        .catch(err => this.handleDeviceError(groupName, err));
    }

    this.setState({
      phase: "ok",
      groups: groupMap
    });

    return null; // handle getDevices asynchronously
  }

  handleGroupsError(err) {
    this.setState({
      phase: "err",
      error: err
    });
  }

  handleDeviceList(groupName, response) {
    let deviceList = response.data.map((value, index) => {
      return Device.fromObject(value);
    });

    let groupMap = this.state.groups;
    let newGroupState = groupMap.get(groupName);
    newGroupState.loading = false;
    newGroupState.totalDevices = deviceList.length;

    let connectedDevices = deviceList.filter(device => device.connected);
    newGroupState.connectedDevices = connectedDevices.length;

    groupMap.set(groupName, newGroupState);

    this.setState({
      groups: groupMap
    });
  }

  handleDeviceError(groupName, err) {
    console.log(`Couldn't get the device list for group ${groupName}`);
    console.log(err);
  }

  goNewGroupPage() {
    this.props.history.push({ pathname: "/groups/new" });
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        if (this.state.groups.size > 0) {
          innerHTML = this.renderGroupsTable();
        } else {
          innerHTML = <p>No registered group</p>;
        }
        break;

      case "err":
        innerHTML = <p>Couldn't load groups</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return (
      <SingleCardPage title="Groups">
        {innerHTML}
        <Button className="float-right" onClick={this.goNewGroupPage}>
          Create new group
        </Button>
      </SingleCardPage>
    );
  }

  renderGroupsTable() {
    return (
      <Table responsive>
        <thead>
          <tr>
            <th>Group name</th>
            <th>Connected devices</th>
            <th>Total devices</th>
          </tr>
        </thead>
        <tbody>
          {Array.from(this.state.groups.values()).map((group, index) => {
            return (
              <tr key={group.name}>
                <td>
                  <Link to={`/groups/${group.name}`}>{group.name}</Link>
                </td>
                <td>{group.connectedDevices}</td>
                <td>{group.totalDevices}</td>
              </tr>
            );
          })}
        </tbody>
      </Table>
    );
  }
}
