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

import React, { useEffect, useState } from "react";
import { Card, Container, Spinner, Table } from "react-bootstrap";

import Device from "./astarte/Device.js";
import BackButton from "./ui/BackButton.js";
import WaitForData from "./components/WaitForData.js";
import useFetch from "./hooks/useFetch.js";
import { useAlerts } from "./AlertManager";

const MAX_SHOWN_VALUES = 20;

const DeviceInterfaceValues = ({ astarte, hisory, deviceId, interfaceName }) => {
  const [ interfaceType, setInterfaceType ] = useState(null);
  const deviceData = useFetch(() => astarte.getDeviceData({
    deviceId: deviceId,
    interfaceName: interfaceName,
  }));

  const deviceAlerts = useAlerts();

  useEffect(() => {
    const getInterfaceType = async () => {
      const deviceInfos = await astarte.getDeviceInfo(deviceId)
        .catch(() => { throw new Error('Device not found.'); });
      const device = Device.fromObject(deviceInfos.data);
      const interfaceIntrospection = device.introspection[interfaceName];

      if (!interfaceIntrospection) {
        throw new Error('Interface not found in device introspection.');
      }

      const interfaceSrc = await astarte.getInterface({
        interfaceName: interfaceName,
        interfaceMajor: interfaceIntrospection.major,
      })
        .catch(() => { throw new Error('Could not retrieve interface properties.'); });

      const interfaceData = interfaceSrc.data;

      if (interfaceData.type == 'properties') {
        setInterfaceType('properties');
      } else if (interfaceData.type == 'datastream' && interfaceData.aggregation == 'object') {
        setInterfaceType('datastream-object');
      } else {
        setInterfaceType('datastream-individual');
      }
    };

    getInterfaceType()
      .catch((err) => {
        deviceAlerts.showError(err.message);
      });
  }, []);

  return (
    <Container fluid className="p-3">
      <h2><BackButton href={`/devices/${deviceId}`} />Interface Data</h2>
      <Card className="mt-4">
        <Card.Header>
          <span className="text-monospace">{deviceId}</span> / {interfaceName}
        </Card.Header>
        <Card.Body>
          <deviceAlerts.Alerts />
          <WaitForData
            data={deviceData.value}
            status={deviceData.status}
            fallback={<Spinner animation="border" role="status" />}
          >
            {(interfaceData) => (
              <InterfaceData data={interfaceData} type={interfaceType} />
            )}
          </WaitForData>
        </Card.Body>
      </Card>
    </Container>
  );
};

const InterfaceData = ({data, type}) => {
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
          <ObjectDatastreamTable data={data.slice(0, MAX_SHOWN_VALUES)} />
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

  // TODO autodetect interface type from data structure
  return null;
};

const PropertyTree = ({data}) => (
  <pre>
    <code>
      {JSON.stringify(data, null, 2)}
    </code>
  </pre>
);

const IndividualDatastreamTable = ({data}) => {
  const paths = linearizePathTree("", data);

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
};

const IndividualDatastreamRow = ({path, value, timestamp}) => (
  <tr>
    <td>{path}</td>
    <td>{value}</td>
    <td>{new Date(timestamp).toLocaleString()}</td>
  </tr>
);

const ObjectDatastreamTable = ({data}) => {
  const labels = [];

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
};

const ObjectDatastreamRow = ({labels, obj}) => (
  <tr>
    { labels.map((label) => <td key={label}>{obj[label]}</td>) }
    <td>{new Date(obj.timestamp).toLocaleString()}</td>
  </tr>
);

function linearizePathTree(prefix, data) {
  return Object.entries(data).map(([key, value]) => linearizeHelper(prefix, key, value)).flat();
}

function linearizeHelper(prefix, key, value) {
  const newPrefix = prefix + "/" + key;

  if (value.value && typeof value.value !== 'object') {
    return {
      path: newPrefix,
      value: value.value,
      timestamp: value.timestamp
    };
  } else {
    return linearizePathTree(newPrefix, value).flat();
  }
}

export default DeviceInterfaceValues;
