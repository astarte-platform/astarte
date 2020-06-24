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
import { Card, Container, Spinner, Table } from "react-bootstrap";

import Device from "./astarte/Device.js";
import BackButton from "./ui/BackButton.js";

export default class DeviceInterfaceValues extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.handleDeviceResponse = this.handleDeviceResponse.bind(this);
    this.handleDeviceError = this.handleDeviceError.bind(this);
    this.handleDataResponse = this.handleDataResponse.bind(this);
    this.handleDataError = this.handleDataError.bind(this);
    this.handleInterfaceResponse = this.handleInterfaceResponse.bind(this);
    this.handleInterfaceError = this.handleInterfaceError.bind(this);

    this.state = {
      phase: "loading"
    }

    this.MAX_VALUES = 20;

    this.astarte
      .getDeviceInfo(props.deviceId)
      .then(this.handleDeviceResponse)
      .catch(this.handleDeviceError);
  }

  handleDeviceResponse(response) {
    const device = Device.fromObject(response.data);
    const { interfaceName } = this.props;

    const interfaceIntrospection = device.introspection[this.props.interfaceName];
    if (interfaceIntrospection) {
      const interfaceId = {
        name: interfaceName,
        major: interfaceIntrospection.major,
        minor: interfaceIntrospection.minor
      }

      this.setState({
        device: device,
        interfaceId: interfaceId
      });

      this.astarte
        .getInterface({
          interfaceName: interfaceId.name,
          interfaceMajor: interfaceId.major
        })
        .then(this.handleInterfaceResponse)
        .catch(this.handleInterfaceError)
        .finally(() => {
          this.astarte
            .getDeviceData({
              deviceId: device.id,
              interfaceName: interfaceId.name
            })
            .then(this.handleDataResponse)
            .catch(this.handleDataError);
        });

    } else {
      this.setState({
        phase: "err",
        errorMessage: "Interface not found in device introspection."
      });
    }
  }

  handleDataResponse(response) {
    let interfaceData;

    switch (this.state.interfaceType) {
      case "properties":
        interfaceData = response.data;
        break;

      case "datastream-object":
        interfaceData = response.data.slice(0, this.MAX_VALUES);
        break;

      case "datastream-individual":
        interfaceData = response.data;
        break;
    }

    this.setState({
      phase: "ok",
      interfaceData: interfaceData
    });
  }

  handleInterfaceResponse(response) {
    const interfaceSrc = response.data;

    let interfaceType;

    if (interfaceSrc.type == "properties") {
      interfaceType = "properties";

    } else if (interfaceSrc.type == "datastream" && interfaceSrc.aggregation == "object") {
      interfaceType = "datastream-object";

    } else {
      interfaceType = "datastream-individual";
    }

    this.setState({
      interfaceType: interfaceType
    });
  }

  handleDeviceError(err) {
    console.log(err);
    this.setState({
      phase: "err",
      errorMessage: "Device not found."
    });
  }

  handleDataError(err) {
    console.log(err);
    this.setState({
      phase: "err",
      errorMessage: "Could not retrieve device data."
    });
  }

  handleInterfaceError(err) {
    // TODO autodetect interface type from returned data
    console.log(err);
    this.setState({
      phase: "err",
      errorMessage: "Could not retrieve interface properties."
    });
  }

  render() {
    const { deviceId, interfaceName } = this.props;
    const { device, interfaceData, interfaceId, interfaceType, phase } = this.state;

    let innerHTML;

    switch (phase) {
      case "ok":
        innerHTML = <InterfaceData data={interfaceData} type={interfaceType} />;
        break;

      case "err":
        innerHTML = <p>{this.state.errorMessage}</p>;
        break;

      default:
        innerHTML = (
          <div>
            <Spinner animation="border" role="status" />
          </div>
        );
        break;
    }

    return (
      <Container fluid className="p-3">
        <h2><BackButton href={`/devices/${deviceId}`} />Interface Data</h2>
        <Card className="mt-4">
          <Card.Header>
            <span className="text-monospace">{deviceId}</span> / {interfaceName}
          </Card.Header>
          <Card.Body>
            {innerHTML}
          </Card.Body>
        </Card>
      </Container>
    );
  }
}

function InterfaceData({data, type}) {
  switch (type) {
    case "properties":
      return (
        <PropertyTree data={data} />
      );

    case "datastream-object":
      if (data.length > 0) {
        return (
          <>
            <h5 className="mb-1">Latest sent objects</h5>
            <ObjectDatastreamTable data={data} />
          </>
        );
      } else {
        return (
          <p>No data sent by the device.</p>
        );
      }

    case "datastream-individual":
      return (
        <IndividualDatastreamTable data={data} />
      );
  }

  return null;
}

function PropertyTree({data}) {
  return (
    <pre>
      <code>
        {JSON.stringify(data, null, 2)}
      </code>
    </pre>
  );
}

function IndividualDatastreamTable({data}) {
  let paths = linearizePathTree("", data);

  return (
    <Table>
      <thead>
        <tr>
          <th>Path</th>
          <th>Last value</th>
          <th>Last timestamp</th>
        </tr>
      </thead>
      <tbody>
        { paths.map(({path, value, timestamp}) =>
          <IndividualDatastreamRow
            key={path}
            path={path}
            value={value}
            timestamp={timestamp}
          />
        )}
      </tbody>
    </Table>
  );
}

function IndividualDatastreamRow({path, value, timestamp}) {
  return (
    <tr>
      <td>{path}</td>
      <td>{value}</td>
      <td>{new Date(timestamp).toLocaleString()}</td>
    </tr>
  );
}

function ObjectDatastreamTable({data}) {
  let labels = [];

  for (let prop in data[0]) {
    if (prop != "timestamp") {
      labels.push(prop);
    }
  }

  return (
    <Table>
      <thead>
        <tr>
          { labels.map((label) => <th key={label}>{label}</th>) }
          <th>Timestamp</th>
        </tr>
      </thead>
      <tbody>
        { data.map((obj) => <ObjectDatastreamRow key={obj.timestamp} labels={labels} obj={obj} />) }
      </tbody>
    </Table>
  );
}

function ObjectDatastreamRow({labels, obj}) {
  return (
    <tr>
      { labels.map((label) => <td key={label}>{obj[label]}</td>) }
      <td>{new Date(obj.timestamp).toLocaleString()}</td>
    </tr>
  );
}

function linearizePathTree(prefix, data) {
  return Object.entries(data).map(([key, value]) => linearizeHelper(prefix, key, value)).flat();
}

function linearizeHelper(prefix, key, value) {
  const newPrefix = prefix + "/" + key;

  if (typeof value.value !== 'object' && value.value !== null) {
    return {
      path: newPrefix,
      value: value.value,
      timestamp: value.timestamp
    };
  } else {
    return linearizePathTree(newPrefix, value).flat();
  }
}
