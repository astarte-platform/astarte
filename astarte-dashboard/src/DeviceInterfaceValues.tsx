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

import React, { ChangeEvent, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { Button, Card, Col, Container, Form, Modal, Row, Spinner, Table } from 'react-bootstrap';
import {
  AstarteDataTuple,
  AstarteDataTreeNode,
  AstartePropertyData,
  AstarteDatastreamIndividualData,
  AstarteDatastreamObjectData,
  AstarteInterface,
  AstarteMapping,
  AstarteDataValue,
  AstarteDataType,
} from 'astarte-client';
import _ from 'lodash';

import BackButton from './ui/BackButton';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import { useAstarte } from './AstarteManager';
import { AlertsBanner, useAlerts } from 'AlertManager';
import * as yup from 'yup';
import { getValidationSchema } from 'astarte-client/models/InterfaceValue';

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

interface SendInterfaceDataModalProps {
  showModal: boolean;
  interfaceDefinition: AstarteInterface;
  sendingData: boolean;
  handleShowModal: () => void;
  sendInterfaceData: (data: { endpoint: string; value: any }) => void;
}

const SendInterfaceDataModal = ({
  showModal,
  sendingData,
  interfaceDefinition,
  handleShowModal,
  sendInterfaceData,
}: SendInterfaceDataModalProps) => {
  const [selectedMapping, setSelectedMapping] = useState<AstarteMapping | null>(null);
  const [endpoint, setEndpoint] = useState('');
  const [endpointWithParams, setEndpointWithParams] = useState('');
  const [paramValues, setParamValues] = useState<{ [key: string]: string }>({});
  const [pathParams, setPathParams] = useState<string[]>([]);
  const [value, setValue] = useState('');
  const [parsedIndividualValue, setParsedIndividualValue] = useState<AstarteDataValue>();
  const [data, setData] = useState<{ [key: string]: string }>({});
  const [parsedObjectData, setParsedObjectData] = useState<{ [key: string]: AstarteDataValue }>({});
  const [errors, setErrors] = useState<{ [key: string]: string }>({});

  const parseValue = (type: AstarteDataType, value: string) => {
    switch (type) {
      case 'string':
      case 'binaryblob':
      case 'datetime':
        return value;
      case 'integer':
      case 'longinteger':
        return parseInt(value, 10);
      case 'double':
        return parseFloat(value);
      case 'boolean':
        return value.toLowerCase() === 'true';
      case 'doublearray':
      case 'integerarray':
      case 'booleanarray':
      case 'longintegerarray':
      case 'stringarray':
      case 'binaryblobarray':
      case 'datetimearray':
        return JSON.parse(value);
    }
  };

  const handleSelectedMapping = (e: ChangeEvent<HTMLSelectElement>) => {
    const selected = interfaceDefinition?.mappings.find(
      (mapping) => mapping.endpoint === e.target.value,
    );
    setSelectedMapping((selected as AstarteMapping) || null);
    setEndpoint(e.target.value);
    setValue('');
    setParamValues({});
    setErrors({});
  };

  type FormControlElement = HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;

  const handleValueChange = (e: ChangeEvent<FormControlElement>) => {
    setValue(e.target.value);
    setErrors({});
  };

  const handleParamChange = (paramName: string, paramValue: string) => {
    setParamValues((prevValues) => ({ ...prevValues, [paramName]: paramValue }));
  };

  const handleObjectData = (dataName: string, dataValue: string) => {
    const mapping = interfaceDefinition?.mappings.find((m) => {
      const segments = m.endpoint.split('/');
      return segments[segments.length - 1] === dataName;
    });
    if (mapping) {
      setData((prevValues) => ({
        ...prevValues,
        [dataName]: dataValue,
      }));
      const schema = getValidationSchema(mapping.type);
      schema
        .validate(dataValue)
        .then(() => {
          setParsedObjectData((prevValues) => ({
            ...prevValues,
            [dataName]: parseValue(mapping.type, dataValue),
          }));
          setErrors((prevErrors) => ({ ...prevErrors, [dataName]: '' }));
        })
        .catch((err) => {
          setErrors((prevErrors) => ({ ...prevErrors, [dataName]: err.message }));
        });
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    sendInterfaceData({
      endpoint: endpointWithParams,
      value:
        interfaceDefinition?.aggregation === 'object' ? parsedObjectData : parsedIndividualValue,
    });
  };

  useEffect(() => {
    const pathParamsArray = AstarteMapping.getEndpointParameters(endpoint);
    setPathParams(pathParamsArray);
  }, [endpoint]);

  useEffect(() => {
    let formattedEndpoint = endpoint;
    pathParams.forEach((param) => {
      formattedEndpoint = formattedEndpoint.replace(`%{${param}}`, paramValues[param] || '');
    });
    setEndpointWithParams(formattedEndpoint);
    if (selectedMapping) {
      const schema = yup.object().shape({
        value: getValidationSchema(selectedMapping.type),
      });
      schema
        .validate({ value })
        .then(() => {
          setParsedIndividualValue(parseValue(selectedMapping.type, value));
        })
        .catch((err) => {
          setErrors({ value: err.message });
        });
    }
    if (interfaceDefinition?.aggregation === 'object') {
      const endpoints: string[] = interfaceDefinition.mappings.map((mapping) => mapping.endpoint);
      const endpointParts: string[][] = endpoints.map((endpoint) => endpoint.split('/'));
      const commonParts: string[] = [];
      for (let i = 0; i < endpointParts[0].length; i++) {
        const currentPart: string = endpointParts[0][i];
        if (endpointParts.every((parts) => parts[i] === currentPart)) {
          commonParts.push(currentPart);
        } else {
          break;
        }
      }
      setEndpoint(commonParts.join('/'));

      interfaceDefinition.mappings.forEach((mapping) => {
        const path: string = mapping.endpoint.split('/').pop() || '';
        data[path] = '';
      });
    }
  }, [value, pathParams, paramValues]);

  return (
    <Modal size="lg" centered show={showModal} onHide={handleShowModal}>
      <Form onSubmit={handleSubmit}>
        <Modal.Header closeButton>
          <Modal.Title>Publish data to interface</Modal.Title>
        </Modal.Header>

        <Modal.Body>
          {(interfaceDefinition?.aggregation === 'individual' ||
            interfaceDefinition?.type === 'properties') && (
            <Form.Group as={Col} controlId="formEndpoint" className="mb-3">
              <Form.Select as="select" value={endpoint} onChange={handleSelectedMapping}>
                <option value="">Choose an endpoint for sending data</option>
                {interfaceDefinition?.mappings.map((mapping, index) => (
                  <option key={index} value={mapping.endpoint}>
                    {mapping.endpoint}
                  </option>
                ))}
              </Form.Select>
            </Form.Group>
          )}

          {!!pathParams.length && (
            <Row className="d-flex justify-content-start my-4">
              <p className="m-0">Please enter endpoint parameters:</p>
              {pathParams.map((param, index) => (
                <Col key={index} md="4" className="my-2">
                  <Form.Group controlId={`param_${index}`}>
                    <Form.Control
                      type="text"
                      required
                      placeholder={param}
                      value={paramValues[param] || ''}
                      onChange={(e) => handleParamChange(param, e.target.value)}
                      isInvalid={!paramValues[param]}
                    />
                  </Form.Group>
                </Col>
              ))}
            </Row>
          )}

          {selectedMapping && (
            <Form.Group as={Col} controlId="formValue">
              <Form.Label className="m-0">Please enter the value:</Form.Label>
              {selectedMapping.type === 'boolean' ? (
                <Form.Select value={value} onChange={handleValueChange} isInvalid={!!errors.value}>
                  <option value="">Select a value</option>
                  <option value="true">true</option>
                  <option value="false">false</option>
                </Form.Select>
              ) : (
                <Form.Control
                  type={
                    selectedMapping.type === 'integer' ||
                    // TODO: Long integer should not be number, validate them with BigInt, and send them to Astarte as strings.
                    selectedMapping.type === 'longinteger' ||
                    selectedMapping.type === 'double'
                      ? 'number'
                      : 'text'
                  }
                  value={value}
                  onChange={handleValueChange}
                  isInvalid={!!errors.value}
                />
              )}
              <Form.Control.Feedback type="invalid">{errors.value}</Form.Control.Feedback>
            </Form.Group>
          )}

          {interfaceDefinition?.aggregation === 'object' && (
            <Row className="d-flex justify-content-start mt-1">
              <p className="m-0">Please enter values:</p>
              {Object.keys(data).map((param, index) => {
                const paramType = interfaceDefinition.mappings[index].type;
                return (
                  <Col key={index} md="4" className="my-2">
                    <Form.Group controlId={`data_${index}`}>
                      {paramType === 'boolean' ? (
                        <Form.Select
                          value={data[param] || ''}
                          required
                          onChange={(e) => handleObjectData(param, e.target.value)}
                          isInvalid={!!errors[param]}
                        >
                          <option value="">Select a value</option>
                          <option value="true">true</option>
                          <option value="false">false</option>
                        </Form.Select>
                      ) : (
                        <Form.Control
                          type={
                            paramType === 'integer' ||
                            // TODO: Long integer should not be number, validate them with BigInt, and send them to Astarte as strings.
                            paramType === 'longinteger' ||
                            paramType === 'double'
                              ? 'number'
                              : 'text'
                          }
                          placeholder={param}
                          value={data[param] || ''}
                          required
                          onChange={(e) => handleObjectData(param, e.target.value)}
                          isInvalid={!!errors[param]}
                        />
                      )}
                      <Form.Control.Feedback type="invalid">{errors[param]}</Form.Control.Feedback>
                    </Form.Group>
                  </Col>
                );
              })}
            </Row>
          )}
        </Modal.Body>

        <Modal.Footer>
          <Button variant="danger" onClick={handleShowModal}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" disabled={sendingData || !!errors.value}>
            {sendingData ? (
              <Spinner className="me-2" size="sm" animation="border" role="status" />
            ) : (
              'Send Data'
            )}
          </Button>
        </Modal.Footer>
      </Form>
    </Modal>
  );
};

export default (): React.ReactElement => {
  const { deviceId = '', interfaceName = '' } = useParams();
  const astarte = useAstarte();
  const deviceDataFetcher = useFetch(() =>
    astarte.client.getDeviceDataTree({
      deviceId,
      interfaceName,
    }),
  );
  const [showModal, setShowModal] = useState(false);
  const [sendingData, setSendingData] = useState(false);
  const [formAlerts, formAlertsController] = useAlerts();
  const iface = deviceDataFetcher.value?.interface as AstarteInterface;

  const handleShowModal = () => {
    setShowModal(!showModal);
  };

  const sendInterfaceData = (data: { endpoint: string; value: AstarteDataValue }) => {
    setSendingData(true);
    astarte.client
      .sendDataToInterface({ deviceId, interfaceName, path: data.endpoint, data: data.value })
      .then(() => {
        handleShowModal();
        deviceDataFetcher.refresh();
      })
      .catch((err) => {
        formAlertsController.showError(
          `Could not send data to interface: ${err.response.data.errors.detail}`,
        );
        handleShowModal();
      })
      .finally(() => {
        setSendingData(false);
      });
  };

  return (
    <Container fluid className="p-3">
      <div className="d-flex justify-content-between">
        <h2>
          <BackButton href={`/devices/${deviceId}/edit`} />
          Interface Data
        </h2>
        {astarte.token?.can(
          'appEngine',
          'POST',
          `devices/${deviceId}/interfaces/${interfaceName}`,
        ) &&
          iface?.ownership === 'server' && (
            <Button onClick={handleShowModal} className="m-2">
              Publish Data
            </Button>
          )}
      </div>
      <AlertsBanner alerts={formAlerts} />
      <Card className="mt-4">
        <Card.Header>
          <span className="font-monospace">{deviceId}</span> /{interfaceName}
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
      {showModal && (
        <SendInterfaceDataModal
          showModal={showModal}
          interfaceDefinition={iface}
          sendingData={sendingData}
          handleShowModal={handleShowModal}
          sendInterfaceData={sendInterfaceData}
        />
      )}
    </Container>
  );
};
