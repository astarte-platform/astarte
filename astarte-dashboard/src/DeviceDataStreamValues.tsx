/*
   This file is part of Astarte.

   Copyright 2024 SECO Mind Srl

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

import React, { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';
import { Card, Container, Table } from 'react-bootstrap';
import {
  AstarteDataTuple,
  AstarteDataValue,
  AstarteDatastreamIndividualData,
  AstarteDatastreamObjectData,
  AstarteInterface,
  AstarteInterfaceValues,
} from 'astarte-client';
import _ from 'lodash';

import BackButton from './ui/BackButton';
import { useAstarte } from './AstarteManager';
import { AlertsBanner, useAlerts } from 'AlertManager';
import 'react-datepicker/dist/react-datepicker.css';
import FiltersForm from 'components/FiltersForm';
import useFetch from 'hooks/useFetch';

function formatAstarteData(data?: AstarteDataTuple): string {
  if (data == null) {
    return '';
  }
  if (_.isArray(data)) {
    return JSON.stringify(data);
  }
  if (_.isBoolean(data)) {
    return data ? 'true' : 'false';
  }
  if (_.isNumber(data)) {
    return data.toString();
  }
  if (_.isNull(data)) {
    return '';
  }
  return String(data);
}

function mapValueToAstarteDataTuple(value: AstarteDataValue): AstarteDataTuple {
  if (_.isNumber(value)) {
    return { type: 'double', value };
  } else if (_.isBoolean(value)) {
    return { type: 'boolean', value };
  } else if (_.isString(value)) {
    return { type: 'string', value };
  } else if (_.isArray(value)) {
    if (value.length > 0) {
      if (_.isNumber(value[0])) {
        return { type: 'doublearray', value: value as number[] };
      } else if (_.isBoolean(value[0])) {
        return { type: 'booleanarray', value: value as boolean[] };
      } else if (_.isString(value[0])) {
        return { type: 'stringarray', value: value as string[] };
      }
    }
    return { type: 'binaryblobarray', value: [] };
  }
  return { type: 'binaryblob', value: null };
}

const transformAggregatedDatastreamInterfaceValues = (
  selectedPath: string,
  fetchedData: AstarteInterfaceValues,
): AstarteDatastreamObjectData[] => {
  const transformedAggregatedDatastreamValues: AstarteDatastreamObjectData[] = [];

  const handleAggregatedDatastreamValues = (aggregatedDatastreamData: any) => {
    if (Array.isArray(aggregatedDatastreamData)) {
      aggregatedDatastreamData.forEach(handleAggregatedDatastreamValues);
    } else if (aggregatedDatastreamData && typeof aggregatedDatastreamData === 'object') {
      if ('timestamp' in aggregatedDatastreamData) {
        const { timestamp, ...valueData } = aggregatedDatastreamData;
        transformedAggregatedDatastreamValues.push({
          endpoint: selectedPath,
          timestamp,
          value: valueData,
        });
      } else {
        Object.values(aggregatedDatastreamData).forEach(handleAggregatedDatastreamValues);
      }
    }
  };

  handleAggregatedDatastreamValues(fetchedData);
  return transformedAggregatedDatastreamValues;
};

const transformIndividualDatastreamInterfaceValues = (
  selectedPath: string,
  fetchedData: AstarteInterfaceValues,
): AstarteDatastreamIndividualData[] => {
  const transformedIndividualDatastreamValues: AstarteDatastreamIndividualData[] = [];

  const handleIndividualDatastreamValues = (individualDatastreamData: any) => {
    if (Array.isArray(individualDatastreamData)) {
      individualDatastreamData.forEach((data) => {
        if (data && typeof data === 'object' && 'timestamp' in data && 'value' in data) {
          const { timestamp, value } = data;
          transformedIndividualDatastreamValues.push({
            endpoint: selectedPath,
            timestamp,
            ...mapValueToAstarteDataTuple(value),
          });
        }
      });
    } else if (individualDatastreamData && typeof individualDatastreamData === 'object') {
      Object.values(individualDatastreamData).forEach(handleIndividualDatastreamValues);
    }
  };

  handleIndividualDatastreamValues(fetchedData);
  return transformedIndividualDatastreamValues;
};

interface IndividualDatastreamTableProps {
  data: AstarteDatastreamIndividualData[];
}

const IndividualDatastreamTable = ({
  data,
}: IndividualDatastreamTableProps): React.ReactElement => {
  return (
    <Table responsive>
      <thead>
        <tr>
          <th>Path</th>
          <th>Value</th>
          <th>Timestamp</th>
        </tr>
      </thead>
      <tbody>
        {data.map((tree, index) => (
          <tr key={index}>
            <td>{tree.endpoint}</td>
            <td>{tree.value}</td>
            <td>{new Date(tree.timestamp).toLocaleString()}</td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
};

interface ObjectDatastreamTableProps {
  data: AstarteDatastreamObjectData[];
}

const ObjectDatastreamTable = ({ data }: ObjectDatastreamTableProps): React.ReactElement => {
  const objectProperties = Object.keys(data[0].value);
  return (
    <>
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
          {data.map((tree) => (
            <tr key={tree.timestamp}>
              {objectProperties.map((property) => (
                <td key={property}>{formatAstarteData(tree.value[property])}</td>
              ))}
              <td>{new Date(tree.timestamp).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </Table>
    </>
  );
};

interface InterfaceDataProps {
  interfaceData: AstarteDatastreamIndividualData[] | AstarteDatastreamObjectData[];
  aggregation: AstarteInterface['aggregation'];
}

const InterfaceData = ({ interfaceData, aggregation }: InterfaceDataProps): React.ReactElement => {
  if (interfaceData.length === 0) {
    return <p>No data in the selected timeframe.</p>;
  } else if (aggregation === 'individual') {
    return <IndividualDatastreamTable data={interfaceData as AstarteDatastreamIndividualData[]} />;
  }
  return <ObjectDatastreamTable data={interfaceData as AstarteDatastreamObjectData[]} />;
};

export default (): React.ReactElement => {
  const { interfaceName = '', deviceId = '', interfaceMajor } = useParams();
  const astarte = useAstarte();
  const [requestingData, setRequestingData] = useState(false);
  const [fetchedData, setFetchedData] = useState<AstarteInterfaceValues | null>(null);
  const [formAlerts, formAlertsController] = useAlerts();
  const [interfaceData, setInterfaceData] = useState<AstarteInterface | null>(null);
  const [selectedPath, setSelectedPath] = useState<string>('');

  const deviceDataFetcher = useFetch(() =>
    astarte.client.getDeviceDataTree({
      deviceId,
      interfaceName,
    }),
  );

  const interfacePaths = useMemo(() => {
    if (deviceDataFetcher.value == null) {
      return [];
    } else if (deviceDataFetcher.value.dataKind === 'datastream_individual') {
      return deviceDataFetcher.value.toLinearizedData().map((data) => data.endpoint);
    } else {
      return deviceDataFetcher.value.getLeaves().map((data) => data.endpoint);
    }
  }, [deviceDataFetcher.value]);

  const fetchData = async (path: string, since?: string, to?: string) => {
    setRequestingData(true);
    setFetchedData(null);
    astarte.client
      .getDeviceData({
        deviceId,
        interfaceName,
        path,
        since,
        to,
      })
      .then((data) => {
        setSelectedPath(path);
        setFetchedData(data);
      })
      .catch((err) => {
        formAlertsController.showError(
          `Could not fetch data to interface: ${err.response.data.errors.detail}`,
        );
        setFetchedData([]);
      })
      .finally(() => {
        setRequestingData(false);
      });
  };

  const transformedData =
    interfaceData && fetchedData
      ? interfaceData.aggregation === 'individual'
        ? transformIndividualDatastreamInterfaceValues(selectedPath, fetchedData)
        : transformAggregatedDatastreamInterfaceValues(selectedPath, fetchedData)
      : [];

  useEffect(() => {
    if (interfaceMajor) {
      const major = parseInt(interfaceMajor, 10);
      astarte.client
        .getInterface({ interfaceName, interfaceMajor: major })
        .then((interfaceData) => {
          setInterfaceData(interfaceData);
        });
    }
  }, []);

  return (
    <Container fluid className="p-3">
      <div className="d-flex justify-content-between">
        <h2>
          <BackButton href={`/devices/${deviceId}/interfaces/${interfaceName}/${interfaceMajor}`} />
          Interface Datastream Data
        </h2>
      </div>
      <AlertsBanner alerts={formAlerts} />
      <Card className="mt-4">
        <Card.Header>
          <span className="font-monospace">{deviceId}</span> /{interfaceName}
        </Card.Header>
        <Card.Body>
          <FiltersForm
            interfacePaths={interfacePaths}
            onFiltersChange={fetchData}
            isLoading={requestingData}
          />
          {fetchedData && (
            <InterfaceData
              interfaceData={transformedData}
              aggregation={interfaceData?.aggregation}
            />
          )}
        </Card.Body>
      </Card>
    </Container>
  );
};
