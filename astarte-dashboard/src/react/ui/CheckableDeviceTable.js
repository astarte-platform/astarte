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
import { Form, Table } from "react-bootstrap";

export default class CheckableDeviceTable extends React.Component {
  constructor(props) {
    super(props);

    this.deviceTableRow = this.deviceTableRow.bind(this);
  }

  render() {
    let deviceList = this.props.devices;
    const filterKey = this.props.filter;

    if (filterKey) {
      deviceList = deviceList.filter(device => {
        const aliases = Array.from(device.aliases.values());

        return (
          aliases.filter(alias => alias.includes(filterKey)).length > 0 ||
          device.id.includes(filterKey)
        );
      });
    }

    if (!deviceList.length) {
      return <p>No device ID matched the current filter</p>;
    }

    return (
      <Table responsive hover>
        <thead>
          <tr>
            <th>Selected</th>
            <th>Device ID</th>
            <th>Aliases</th>
          </tr>
        </thead>
        <tbody>{deviceList.map(this.deviceTableRow)}</tbody>
      </Table>
    );
  }

  deviceTableRow(device, index) {
    const filterKey = this.props.filter;
    const deviceAliases = Array.from(device.aliases.values());

    const selected = this.props.selectedDevices.has(device.id);

    return (
      <tr key={index}>
        <td>
          <Form.Check
            id={`device-${device.id}`}
            type="checkbox"
            data-device-id={device.id}
            checked={selected}
            onChange={this.props.onToggleDevice}
          />
        </td>
        <td>{highlight(device.id, filterKey)}</td>
        <td>
          <ul className="list-unstyled">
            {deviceAliases.map((alias, index) => {
              return <li key={index}>{highlight(alias, filterKey)}</li>;
            })}
          </ul>
        </td>
      </tr>
    );
  }
}

function highlight(word, sub) {
  if (sub) {
    return word.split(sub).reduce((prev, next) => (
      <>
        {prev}
        <span className="bg-warning text-dark">{sub}</span>
        {next}
      </>
    ));
  } else {
    return word;
  }
}
