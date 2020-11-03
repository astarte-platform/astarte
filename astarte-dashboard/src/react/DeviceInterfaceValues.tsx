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

import React, { useEffect, useState } from 'react';
import { Card, Container, Spinner, Table } from 'react-bootstrap';
import AstarteClient from 'astarte-client';
import type {
  AstarteDataType,
  AstarteInterface,
  AstarteInterfaceValues,
  AstartePropertiesInterfaceValues,
  AstarteIndividualDatastreamInterfaceValue,
  AstarteIndividualDatastreamInterfaceValues,
  AstarteAggregatedDatastreamInterfaceValue,
  AstarteAggregatedDatastreamInterfaceValues,
} from 'astarte-client';
import _ from 'lodash';

import BackButton from './ui/BackButton';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import { useAlerts } from './AlertManager';

const MAX_SHOWN_VALUES = 20;

type LinearizedIndividualDatastreamInterfaceValues = Array<{
  path: string;
  value: AstarteDataType;
  timestamp: string;
}>;
type LinearizedAggregatedDatastreamInterfaceValue = Array<{
  [key: string]: AstarteDataType;
  timestamp: string;
}>;
type LinearizedAggregatedDatastreamInterfaceValues = Array<{
  path: string;
  value: LinearizedAggregatedDatastreamInterfaceValue;
}>;

const isIndividualDatastreamInterfaceValue = (
  value: any,
): value is AstarteIndividualDatastreamInterfaceValue =>
  value.value != null && typeof value.value !== 'object';

const isAggregatedDatastreamInterfaceValue = (
  value: any,
): value is AstarteAggregatedDatastreamInterfaceValue => Array.isArray(value);

function linearizeIndividualDatastreamInterfaceValue(
  prefix: string,
  data: AstarteIndividualDatastreamInterfaceValues,
): LinearizedIndividualDatastreamInterfaceValues {
  return Object.entries(data)
    .map(([key, value]) => {
      const newPrefix = `${prefix}/${key}`;
      if (isIndividualDatastreamInterfaceValue(value)) {
        return {
          path: newPrefix,
          value: value.value,
          timestamp: value.timestamp,
        };
      }
      return linearizeIndividualDatastreamInterfaceValue(newPrefix, value).flat();
    })
    .flat();
}

function linearizeAggregatedDatastreamInterfaceValue(
  prefix: string,
  data: AstarteAggregatedDatastreamInterfaceValues,
): LinearizedAggregatedDatastreamInterfaceValues {
  return Object.entries(data)
    .map(([key, value]) => {
      const newPrefix = `${prefix}/${key}`;
      if (isAggregatedDatastreamInterfaceValue(value)) {
        return {
          path: newPrefix,
          value,
        };
      }
      return linearizeAggregatedDatastreamInterfaceValue(newPrefix, value).flat();
    })
    .flat();
}

function formatAstarteDataValue(value: AstarteDataType): string {
  if (_.isArray(value)) {
    return JSON.stringify(value);
  }
  if (_.isBoolean(value)) {
    return value ? 'true' : 'false';
  }
  if (_.isNumber(value)) {
    return value.toString();
  }
  if (_.isNull(value)) {
    return '';
  }
  return String(value);
}

interface PropertyTreeProps {
  data: AstartePropertiesInterfaceValues;
}

const PropertyTree = ({ data }: PropertyTreeProps): React.ReactElement => (
  <pre>
    <code>{JSON.stringify(data, null, 2)}</code>
  </pre>
);

interface IndividualDatastreamTableProps {
  data: AstarteIndividualDatastreamInterfaceValues;
}

const IndividualDatastreamTable = ({
  data,
}: IndividualDatastreamTableProps): React.ReactElement => {
  const paths = linearizeIndividualDatastreamInterfaceValue(
    '',
    data,
  ) as LinearizedIndividualDatastreamInterfaceValues;

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
        {paths.map((obj) => (
          <tr key={obj.path}>
            <td>{obj.path}</td>
            <td>{formatAstarteDataValue(obj.value)}</td>
            <td>{new Date(obj.timestamp).toLocaleString()}</td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
};

interface ObjectDatastreamTableProps {
  path: string;
  values: LinearizedAggregatedDatastreamInterfaceValue;
}

const ObjectDatastreamTable = ({
  path,
  values,
}: ObjectDatastreamTableProps): React.ReactElement => {
  const labels: string[] = [];
  const latestValues = values.slice(0, MAX_SHOWN_VALUES);

  Object.keys(values[0]).forEach((prop) => {
    if (prop !== 'timestamp') {
      labels.push(prop);
    }
  });

  return (
    <>
      <h5 className="mb-1">Path</h5>
      <p>{path}</p>
      <Table>
        <thead>
          <tr>
            {labels.map((label) => (
              <th key={label}>{label}</th>
            ))}
            <th>Timestamp</th>
          </tr>
        </thead>
        <tbody>
          {latestValues.map((obj) => (
            <tr key={obj.timestamp}>
              {labels.map((label) => (
                <td key={label}>{formatAstarteDataValue(obj[label])}</td>
              ))}
              <td>{new Date(obj.timestamp).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </Table>
    </>
  );
};

interface ObjectTableListProps {
  data: AstarteAggregatedDatastreamInterfaceValues;
}

const ObjectTableList = ({ data }: ObjectTableListProps): React.ReactElement => {
  const linearizedData = linearizeAggregatedDatastreamInterfaceValue(
    '',
    data,
  ) as LinearizedAggregatedDatastreamInterfaceValues;
  if (linearizedData.length === 0) {
    return <p>No data sent by the device.</p>;
  }
  return (
    <>
      {linearizedData.map((obj) => (
        <ObjectDatastreamTable key={obj.path} path={obj.path} values={obj.value} />
      ))}
    </>
  );
};

interface InterfaceDataProps {
  interfaceData: AstarteInterfaceValues;
  interfaceDefinition: AstarteInterface;
}

const InterfaceData = ({
  interfaceData,
  interfaceDefinition,
}: InterfaceDataProps): React.ReactElement => {
  if (interfaceDefinition.type === 'properties') {
    return <PropertyTree data={interfaceData as AstartePropertiesInterfaceValues} />;
  }
  if (interfaceDefinition.type === 'datastream' && interfaceDefinition.aggregation === 'object') {
    return <ObjectTableList data={interfaceData as AstarteAggregatedDatastreamInterfaceValues} />;
  }
  return (
    <IndividualDatastreamTable data={interfaceData as AstarteIndividualDatastreamInterfaceValues} />
  );
};

interface Props {
  astarte: AstarteClient;
  deviceId: string;
  interfaceName: string;
}

export default ({ astarte, deviceId, interfaceName }: Props): React.ReactElement => {
  const [interfaceDefinition, setInterfaceDefinition] = useState<AstarteInterface | null>(null);
  const deviceData = useFetch(() =>
    astarte.getDeviceData({
      deviceId,
      interfaceName,
    }),
  );

  const deviceAlerts = useAlerts();

  useEffect(() => {
    if (deviceData.error != null) {
      deviceAlerts.showError('Could not retrieve interface data.');
    }
  }, [deviceData.error]);

  useEffect(() => {
    const getInterfaceType = async () => {
      const device = await astarte.getDeviceInfo(deviceId).catch(() => {
        throw new Error('Device not found.');
      });
      const interfaceIntrospection = device.introspection.get(interfaceName);
      if (!interfaceIntrospection) {
        throw new Error('Interface not found in device introspection.');
      }
      await astarte
        .getInterface({
          interfaceName,
          interfaceMajor: interfaceIntrospection.major,
        })
        .then(setInterfaceDefinition)
        .catch(() => {
          throw new Error('Could not retrieve interface properties.');
        });
    };

    getInterfaceType().catch((err) => {
      deviceAlerts.showError(err.message);
    });
  }, []);

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href={`/devices/${deviceId}`} />
        Interface Data
      </h2>
      <Card className="mt-4">
        <Card.Header>
          <span className="text-monospace">{deviceId}</span> /{interfaceName}
        </Card.Header>
        <Card.Body>
          <deviceAlerts.Alerts />
          <WaitForData
            data={interfaceDefinition && deviceData.value}
            status={interfaceDefinition ? deviceData.status : 'loading'}
            fallback={
              deviceData.error != null ? <></> : <Spinner animation="border" role="status" />
            }
          >
            {(interfaceData) => (
              <InterfaceData
                interfaceData={interfaceData as AstarteInterfaceValues}
                interfaceDefinition={interfaceDefinition as AstarteInterface}
              />
            )}
          </WaitForData>
        </Card.Body>
      </Card>
    </Container>
  );
};
