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

import React from 'react';
import { useParams } from 'react-router-dom';
import { Card, Container, Spinner, Table } from 'react-bootstrap';
import type {
  AstarteDataTuple,
  AstarteDataTreeNode,
  AstartePropertyData,
  AstarteDatastreamIndividualData,
  AstarteDatastreamObjectData,
} from 'astarte-client';
import _ from 'lodash';

import BackButton from './ui/BackButton';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import { useAstarte } from './AstarteManager';

const MAX_SHOWN_VALUES = 20;

function formatAstarteData(data?: AstarteDataTuple): string {
  const value = data?.value;
  if (value == null) {
    return '';
  }
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
  treeNode: AstarteDataTreeNode<AstartePropertyData>;
}

const PropertyTree = ({ treeNode }: PropertyTreeProps): React.ReactElement => (
  <pre>
    <code>{JSON.stringify(treeNode.toLastValue(), null, 2)}</code>
  </pre>
);

interface IndividualDatastreamTableProps {
  treeNode: AstarteDataTreeNode<AstarteDatastreamIndividualData>;
}

const IndividualDatastreamTable = ({
  treeNode,
}: IndividualDatastreamTableProps): React.ReactElement => {
  const dataValues = treeNode.toLinearizedData();
  if (dataValues.length === 0) {
    return <p>No data sent by the device.</p>;
  }

  return (
    <Table responsive>
      <thead>
        <tr>
          <th>Path</th>
          <th>Last value</th>
          <th>Last timestamp</th>
        </tr>
      </thead>
      <tbody>
        {dataValues.map((dataValue) => (
          <tr key={dataValue.endpoint}>
            <td>{dataValue.endpoint}</td>
            <td>{formatAstarteData(dataValue)}</td>
            <td>{new Date(dataValue.timestamp).toLocaleString()}</td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
};

interface ObjectDatastreamTableProps {
  dataTreeNode: AstarteDataTreeNode<AstarteDatastreamObjectData>;
}

const ObjectDatastreamTable = ({
  dataTreeNode,
}: ObjectDatastreamTableProps): React.ReactElement => {
  const treeData = dataTreeNode.toData();
  if (treeData.length === 0) {
    return <p>No data sent by the device.</p>;
  }

  const objectProperties = Object.keys(treeData[0].value);
  const orderedData = _.orderBy(treeData, 'timestamp', 'desc');

  return (
    <>
      <h5 className="mb-1">Path</h5>
      <p>{dataTreeNode.endpoint}</p>
      <Table responsive>
        <thead>
          <tr>
            {objectProperties.map((property) => (
              <th key={property}>{property}</th>
            ))}
            <th>Timestamp</th>
          </tr>
        </thead>
        <tbody>
          {orderedData.slice(0, MAX_SHOWN_VALUES).map((data) => (
            <tr key={data.timestamp}>
              {objectProperties.map((property) => (
                <td key={property}>{formatAstarteData(data.value[property])}</td>
              ))}
              <td>{new Date(data.timestamp).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </Table>
    </>
  );
};

interface ObjectTableListProps {
  treeNode: AstarteDataTreeNode<AstarteDatastreamObjectData>;
}

const ObjectTableList = ({ treeNode }: ObjectTableListProps): React.ReactElement => {
  const dataTreeLeaves = treeNode.getLeaves();
  if (dataTreeLeaves.length === 0) {
    return <p>No data sent by the device.</p>;
  }
  return (
    <>
      {dataTreeLeaves.map((dataTreeLeaf) => (
        <ObjectDatastreamTable key={dataTreeLeaf.endpoint} dataTreeNode={dataTreeLeaf} />
      ))}
    </>
  );
};

interface InterfaceDataProps {
  interfaceData:
    | AstarteDataTreeNode<AstartePropertyData>
    | AstarteDataTreeNode<AstarteDatastreamIndividualData>
    | AstarteDataTreeNode<AstarteDatastreamObjectData>;
}

const InterfaceData = ({ interfaceData }: InterfaceDataProps): React.ReactElement => {
  if (interfaceData.dataKind === 'properties') {
    return <PropertyTree treeNode={interfaceData as AstarteDataTreeNode<AstartePropertyData>} />;
  }
  if (interfaceData.dataKind === 'datastream_individual') {
    return (
      <IndividualDatastreamTable
        treeNode={interfaceData as AstarteDataTreeNode<AstarteDatastreamIndividualData>}
      />
    );
  }
  return (
    <ObjectTableList treeNode={interfaceData as AstarteDataTreeNode<AstarteDatastreamObjectData>} />
  );
};

export default (): React.ReactElement => {
  const { deviceId, interfaceName } = useParams();
  const astarte = useAstarte();
  const deviceDataFetcher = useFetch(() =>
    astarte.client.getDeviceDataTree({
      deviceId,
      interfaceName,
    }),
  );

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href={`/devices/${deviceId}/edit`} />
        Interface Data
      </h2>
      <Card className="mt-4">
        <Card.Header>
          <span className="text-monospace">{deviceId}</span> /{interfaceName}
        </Card.Header>
        <Card.Body>
          <WaitForData
            data={deviceDataFetcher.value}
            status={deviceDataFetcher.status}
            fallback={
              <Container fluid className="text-center">
                <Spinner animation="border" role="status" />
              </Container>
            }
            errorFallback={
              <Empty title="Couldn't load interface data" onRetry={deviceDataFetcher.refresh} />
            }
          >
            {(data) => <InterfaceData interfaceData={data} />}
          </WaitForData>
        </Card.Body>
      </Card>
    </Container>
  );
};
