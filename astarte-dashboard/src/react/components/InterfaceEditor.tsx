/*
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl

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

import React, { useCallback, useEffect, useState } from 'react';
import {
  Accordion,
  Badge,
  Button,
  Card,
  Col,
  Container,
  Form,
  InputGroup,
  Modal,
  Row,
} from 'react-bootstrap';
import { AstarteInterface, AstarteMapping } from 'astarte-client';
import _ from 'lodash';

import MappingEditor from './MappingEditor';

interface FormControlWarningProps {
  message?: string;
}

const FormControlWarning = ({ message }: FormControlWarningProps): React.ReactElement | null => {
  if (!message) {
    return null;
  }
  return <div className="warning-feedback">{message}</div>;
};

interface MappingRowProps {
  className?: string;
  mapping: AstarteMapping;
  onEdit?: () => void;
  onDelete?: () => void;
}

const reliabilityToLabel = {
  unreliable: 'Unreliable',
  guaranteed: 'Guaranteed',
  unique: 'Unique',
};

const retentionToLabel = {
  discard: 'Discard',
  volatile: 'Volatile',
  stored: 'Stored',
};

const databaseRetentionToLabel = {
  no_ttl: 'No TTL',
  use_ttl: 'Use TTL',
};

const MappingRow = ({ className, mapping, onEdit, onDelete }: MappingRowProps) => (
  <Accordion data-testid={mapping.endpoint}>
    <Card className={className}>
      <Accordion.Toggle
        eventKey={mapping.endpoint}
        as={Card.Header}
        className="d-flex align-items-center flex-wrap"
      >
        <span className="flex-grow-1">
          <Badge variant="secondary">{mapping.type}</Badge>
          <Button className="text-left text-truncate" variant="link">
            {mapping.endpoint}
          </Button>
        </span>
        {onEdit && (
          <Button className="mr-2" variant="outline-primary" onClick={onEdit}>
            Edit...
          </Button>
        )}
        {onDelete && (
          <Button variant="outline-primary" onClick={onDelete}>
            Remove
          </Button>
        )}
      </Accordion.Toggle>
      <Accordion.Collapse eventKey={mapping.endpoint}>
        <Card.Body>
          {mapping.description && (
            <>
              <h5>Description</h5>
              <p>{mapping.description}</p>
            </>
          )}
          {mapping.documentation && (
            <>
              <h5>Documentation</h5>
              <p>{mapping.documentation}</p>
            </>
          )}
          {mapping.allowUnset && (
            <>
              <h5>Allow Unset</h5>
              <p>True</p>
            </>
          )}
          {mapping.explicitTimestamp && (
            <>
              <h5>Explicit Timestamp</h5>
              <p>True</p>
            </>
          )}
          {mapping.reliability && (
            <>
              <h5>Reliability</h5>
              <p>{reliabilityToLabel[mapping.reliability]}</p>
            </>
          )}
          {mapping.retention && (
            <>
              <h5>Retention</h5>
              <p>{retentionToLabel[mapping.retention]}</p>
            </>
          )}
          {mapping.expiry && (
            <>
              <h5>Expiry</h5>
              <p>{mapping.expiry} seconds</p>
            </>
          )}
          {mapping.databaseRetentionPolicy && (
            <>
              <h5>Database Retention</h5>
              <p>{databaseRetentionToLabel[mapping.databaseRetentionPolicy]}</p>
            </>
          )}
          {mapping.databaseRetentionTtl != null && (
            <>
              <h5>Database Retention TTL</h5>
              <p>{mapping.databaseRetentionTtl} seconds</p>
            </>
          )}
        </Card.Body>
      </Accordion.Collapse>
    </Card>
  </Accordion>
);

const getDefaultMapping = (params: {
  interfaceType: AstarteInterface['type'];
  interfaceAggregation: AstarteInterface['aggregation'];
}): AstarteMapping => {
  if (params.interfaceType === 'datastream' && params.interfaceAggregation === 'individual') {
    return {
      endpoint: '',
      type: 'double',
      explicitTimestamp: true,
    };
  }
  return {
    endpoint: '',
    type: 'double',
  };
};

interface MappingModalProps {
  interfaceType: AstarteInterface['type'];
  interfaceAggregation?: AstarteInterface['aggregation'];
  mapping?: AstarteMapping;
  onCancel: () => void;
  onConfirm: (newMapping: AstarteMapping) => void;
}

const MappingModal = ({
  interfaceType,
  interfaceAggregation = 'individual',
  mapping,
  onCancel,
  onConfirm,
}: MappingModalProps): React.ReactElement => {
  const [mappingDraft, setMappingDraft] = useState(
    mapping || getDefaultMapping({ interfaceType, interfaceAggregation }),
  );

  const handleChange = useCallback((newMapping: AstarteMapping) => {
    setMappingDraft(newMapping);
  }, []);

  const isValidMapping = AstarteMapping.validation.isValidSync(mappingDraft);

  return (
    <Modal show size="lg" centered onHide={onCancel}>
      <Modal.Header closeButton>
        <Modal.Title>{mapping != null ? 'Edit mapping' : 'Add new mapping'}</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <MappingEditor
          interfaceType={interfaceType}
          interfaceAggregation={interfaceAggregation}
          mapping={mappingDraft}
          onChange={handleChange}
        />
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button
          variant="primary"
          onClick={() => onConfirm(mappingDraft)}
          disabled={!isValidMapping}
        >
          Confirm
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

const computeInterfaceWarnings = (iface: AstarteInterface): { [key: string]: string } => {
  const warnings: { [key: string]: string } = {};

  if (iface.type === 'datastream' && iface.aggregation === 'object') {
    const endpoints = iface.mappings.map((mapping) => mapping.endpoint);
    const endpointDepths = endpoints.map((endpoint) => endpoint.split('/').length - 1);
    if (endpointDepths.some((depth) => depth < 2)) {
      warnings.mappings =
        'Interface mappings endpoints of depth 1 in Object aggregate interfaces are deprecated. The endpoint should have depth level of 2 or more (e.g. /my/endpoint).';
    }
  }

  const interfaceNameRegex = /^([a-z][a-z0-9]*\.([a-z0-9][a-z0-9-]*\.)*)+[A-Z][a-zA-Z0-9]*$/;
  if (!interfaceNameRegex.test(iface.name)) {
    warnings.name =
      'Interface name should be prefixed with a reverse domain name, and should use PascalCase (e.g. com.example.MyInterface)';
  }

  return warnings;
};

const checkInterfaceHasMajorChanges = (
  initialInterface: AstarteInterface,
  draftInterface: AstarteInterface,
) => {
  const sensibleProperties: Array<keyof AstarteInterface> = [
    'name',
    'major',
    'type',
    'aggregation',
    'ownership',
  ];
  const hasPropertyMajorChange = sensibleProperties.some(
    (property) => draftInterface[property] !== initialInterface[property],
  );
  if (hasPropertyMajorChange) {
    return true;
  }
  const hasExistingMappings = initialInterface.mappings.every((initialMapping) => {
    const draftMapping = draftInterface.mappings.find(
      ({ endpoint }) => endpoint === initialMapping.endpoint,
    );
    return _.isEqual(draftMapping, initialMapping);
  });
  if (!hasExistingMappings) {
    return true;
  }
  return false;
};

const formatJSON = (json: unknown): string => JSON.stringify(json, null, 4);

const formatJSONText = (text: string): string => {
  try {
    return formatJSON(JSON.parse(text));
  } catch {
    return text;
  }
};

const checkValidJSONText = (text: string): boolean => {
  try {
    JSON.parse(text);
    return true;
  } catch {
    return false;
  }
};

const defaultInterface: AstarteInterface = {
  name: '',
  major: 0,
  minor: 1,
  type: 'properties',
  ownership: 'device',
  mappings: [],
};

interface DatastreamOptions {
  reliability?: AstarteMapping['reliability'];
  retention?: AstarteMapping['retention'];
  expiry?: AstarteMapping['expiry'];
  databaseRetentionPolicy?: AstarteMapping['databaseRetentionPolicy'];
  databaseRetentionTtl?: AstarteMapping['databaseRetentionTtl'];
  explicitTimestamp?: AstarteMapping['explicitTimestamp'];
}

const defaultDatastreamOptions = {
  explicitTimestamp: true,
};

const getInitialDatastreamOptions = (iface: AstarteInterface): DatastreamOptions => {
  if (iface.mappings.length === 0) {
    return defaultDatastreamOptions;
  }
  const mapping = iface.mappings[0];
  const options: DatastreamOptions = {};
  options.reliability = mapping.reliability;
  options.retention = mapping.retention;
  options.expiry = options.retention !== 'discard' ? mapping.expiry : undefined;
  options.databaseRetentionPolicy = mapping.databaseRetentionPolicy;
  options.databaseRetentionTtl =
    options.databaseRetentionPolicy === 'use_ttl' ? mapping.databaseRetentionTtl : undefined;
  options.explicitTimestamp = mapping.explicitTimestamp != null ? mapping.explicitTimestamp : true;
  return options;
};

interface Props {
  initialData?: AstarteInterface;
  isSourceVisible?: boolean;
  onChange?: (updatedInterface: AstarteInterface, isValid: boolean) => unknown;
  denyMajorChanges?: boolean;
}

export default ({
  initialData,
  isSourceVisible = false,
  onChange,
  denyMajorChanges = false,
}: Props): React.ReactElement => {
  const [interfaceDraft, setInterfaceDraft] = useState<AstarteInterface>(
    initialData || defaultInterface,
  );
  const [interfaceSource, setInterfaceSource] = useState(
    formatJSON(AstarteInterface.toJSON(interfaceDraft)),
  );
  const [datastreamOptions, setDatastreamOptions] = useState<DatastreamOptions>(
    getInitialDatastreamOptions(interfaceDraft),
  );
  const [isMappingModalVisible, setIsMappingModalVisible] = useState(false);
  const [mappingToEditIndex, setMappingToEditIndex] = useState(0);

  const parseAstarteInterfaceJSON = useCallback(
    (json: any): AstarteInterface | null => {
      let parsedInterface: AstarteInterface;
      try {
        parsedInterface = AstarteInterface.fromJSON(json);
      } catch {
        throw new Error('Invalid interface');
      }
      if (
        initialData != null &&
        denyMajorChanges &&
        checkInterfaceHasMajorChanges(initialData, parsedInterface)
      ) {
        throw new Error(
          'Interface cannot have major changes such as updating name, major, type, aggregation, ownership, or editing already existing mappings',
        );
      }
      return parsedInterface;
    },
    [initialData, denyMajorChanges],
  );

  const handleInterfaceNameChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setInterfaceDraft((draft) => ({ ...draft, name: value.trim() }));
  }, []);

  const handleInterfaceMajorChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setInterfaceDraft((draft) => ({ ...draft, major: parseInt(value, 10) }));
  }, []);

  const handleInterfaceMinorChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setInterfaceDraft((draft) => ({ ...draft, minor: parseInt(value, 10) }));
  }, []);

  const clearMappingsOptions = useCallback(
    (params: { type: AstarteInterface['type']; aggregation: AstarteInterface['aggregation'] }) => {
      setInterfaceDraft((draft) => {
        const mappings = draft.mappings.map((mapping) =>
          _.omit(mapping, [
            'allowUnset',
            'reliability',
            'retention',
            'expiry',
            'databaseRetentionPolicy',
            'databaseRetentionTtl',
            'explicitTimestamp',
          ]),
        );
        return { ...draft, mappings };
      });
      if (params.type === 'datastream' && params.aggregation === 'object') {
        setDatastreamOptions(defaultDatastreamOptions);
      } else {
        setDatastreamOptions({});
      }
    },
    [],
  );

  const handleInterfaceTypeChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.currentTarget;
    const type = value as AstarteInterface['type'];
    const aggregation = type === 'datastream' ? 'individual' : undefined;
    clearMappingsOptions({ type, aggregation });
    setInterfaceDraft((draft) => ({ ...draft, type, aggregation }));
  }, []);

  const handleInterfaceAggregationChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.currentTarget;
    const aggregation = value as AstarteInterface['aggregation'];
    clearMappingsOptions({ type: 'datastream', aggregation });
    setInterfaceDraft((draft) => ({
      ...draft,
      aggregation,
    }));
  }, []);

  const handleInterfaceOwnershipChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.currentTarget;
    const ownership = value as AstarteInterface['ownership'];
    setInterfaceDraft((draft) => ({
      ...draft,
      ownership,
    }));
  }, []);

  const handleInterfaceDescriptionChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setInterfaceDraft((draft) => ({ ...draft, description: value || undefined }));
  }, []);

  const handleInterfaceDocumentationChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      setInterfaceDraft((draft) => ({ ...draft, documentation: value || undefined }));
    },
    [],
  );

  const handleInterfaceReliabilityChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.currentTarget;
    let reliability = value as AstarteMapping['reliability'];
    reliability = reliability === 'unreliable' ? undefined : reliability;
    setDatastreamOptions((options) => ({ ...options, reliability }));
  }, []);

  const handleInterfaceExplicitTimestampChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      let explicitTimestamp = !!e.target.checked as AstarteMapping['explicitTimestamp'];
      explicitTimestamp = explicitTimestamp || undefined;
      setDatastreamOptions((options) => ({ ...options, explicitTimestamp }));
    },
    [],
  );

  const handleInterfaceRetentionChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.currentTarget;
    const retention = value as AstarteMapping['retention'];
    setDatastreamOptions((options) => ({
      ...options,
      retention: retention === 'discard' ? undefined : retention,
      expiry: retention === 'discard' ? undefined : options.expiry,
    }));
  }, []);

  const handleInterfaceExpiryChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const expiry = parseInt(e.currentTarget.value, 10) || undefined;
    setDatastreamOptions((options) => ({ ...options, expiry }));
  }, []);

  const handleInterfaceDatabaseRetentionPolicyChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.currentTarget;
      const databaseRetentionPolicy = value as AstarteMapping['databaseRetentionPolicy'];
      setDatastreamOptions((options) => ({
        ...options,
        databaseRetentionPolicy:
          databaseRetentionPolicy === 'no_ttl' ? undefined : databaseRetentionPolicy,
        databaseRetentionTtl:
          databaseRetentionPolicy === 'no_ttl' ? undefined : options.databaseRetentionTtl || 60,
      }));
    },
    [],
  );

  const handleInterfaceDatabaseRetentionTtlChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const databaseRetentionTtl = parseInt(e.currentTarget.value, 10);
      setDatastreamOptions((options) => ({ ...options, databaseRetentionTtl }));
    },
    [],
  );

  const handleAddMapping = useCallback(() => {
    setMappingToEditIndex(interfaceDraft.mappings.length);
    setIsMappingModalVisible(true);
  }, [interfaceDraft.mappings]);

  const handleEditMapping = useCallback((mappingIndex: number) => {
    setMappingToEditIndex(mappingIndex);
    setIsMappingModalVisible(true);
  }, []);

  const handleDeleteMapping = useCallback((mappingIndex: number) => {
    setInterfaceDraft((draft) => {
      const updatedMappings = draft.mappings.filter((m, index) => index !== mappingIndex);
      return { ...draft, mappings: updatedMappings };
    });
  }, []);

  const handleConfirmEditMapping = useCallback(
    (mapping: AstarteMapping) => {
      setInterfaceDraft((draft) => {
        let newMapping = { ...mapping };
        if (interfaceDraft.type === 'datastream' && interfaceDraft.aggregation === 'object') {
          newMapping = { ...mapping, ...datastreamOptions };
        }
        const isNewMapping = mappingToEditIndex >= draft.mappings.length;
        const updatedMappings = isNewMapping
          ? draft.mappings.concat(newMapping)
          : draft.mappings.map((m, index) => (index === mappingToEditIndex ? newMapping : m));
        return { ...draft, mappings: updatedMappings };
      });
      setIsMappingModalVisible(false);
    },
    [mappingToEditIndex, datastreamOptions, interfaceDraft.type, interfaceDraft.aggregation],
  );

  const handleInterfaceSourceChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setInterfaceSource(value);
    if (!checkValidJSONText(value)) {
      return;
    }
    let parsedInterface: AstarteInterface | null;
    try {
      parsedInterface = parseAstarteInterfaceJSON(JSON.parse(value));
    } catch {
      parsedInterface = null;
    }
    if (!parsedInterface) {
      return;
    }
    setInterfaceDraft(parsedInterface);
    const mapping: AstarteMapping | undefined = _.get(parsedInterface, 'mappings.0');
    if (parsedInterface.type === 'datastream' && parsedInterface.aggregation === 'object') {
      setDatastreamOptions({
        reliability: mapping?.reliability,
        retention: mapping?.retention,
        expiry: mapping?.expiry,
        databaseRetentionPolicy: mapping?.databaseRetentionPolicy,
        databaseRetentionTtl: mapping?.databaseRetentionTtl,
        explicitTimestamp: mapping?.explicitTimestamp,
      });
    } else {
      setDatastreamOptions({});
    }
  }, []);

  useEffect(() => {
    setInterfaceDraft((draft) => {
      if (draft.aggregation !== 'object' || draft.mappings.length === 0) {
        return draft;
      }
      const mappings = draft.mappings.map((mapping) => ({
        ...mapping,
        reliability: datastreamOptions.reliability,
        retention: datastreamOptions.retention,
        expiry: datastreamOptions.expiry,
        databaseRetentionPolicy: datastreamOptions.databaseRetentionPolicy,
        databaseRetentionTtl: datastreamOptions.databaseRetentionTtl,
        explicitTimestamp: datastreamOptions.explicitTimestamp,
      }));
      return { ...draft, mappings };
    });
  }, [datastreamOptions]);

  let interfaceValidationErrors: { [key: string]: string } = {};
  try {
    AstarteInterface.validation.validateSync(interfaceDraft, { abortEarly: false });
  } catch (err) {
    interfaceValidationErrors = _.mapValues(
      _.keyBy(_.uniqBy(err.inner, 'path'), 'path'),
      'message',
    );
  }
  const isValidInterface = _.isEmpty(interfaceValidationErrors);

  useEffect(() => {
    const formattedInterfaceSource = formatJSON(AstarteInterface.toJSON(interfaceDraft));
    setInterfaceSource((source) =>
      formatJSONText(source) !== formattedInterfaceSource ? formattedInterfaceSource : source,
    );
    if (onChange) {
      onChange(interfaceDraft, isValidInterface);
    }
  }, [interfaceDraft, isValidInterface]);

  const interfaceValidationWarnings = computeInterfaceWarnings(interfaceDraft);

  let isValidInterfaceSource = true;
  let interfaceSourceError = '';
  if (!checkValidJSONText(interfaceSource)) {
    isValidInterfaceSource = false;
    interfaceSourceError = 'Invalid JSON';
  } else {
    try {
      parseAstarteInterfaceJSON(JSON.parse(interfaceSource));
    } catch (err) {
      isValidInterfaceSource = false;
      interfaceSourceError = err.message;
    }
  }

  const mappingToEdit = _.nth(interfaceDraft.mappings, mappingToEditIndex);

  const showInterfaceExpiry =
    datastreamOptions.retention === 'volatile' || datastreamOptions.retention === 'stored';

  const showInterfaceDatabaseRetentionTtl = datastreamOptions.databaseRetentionPolicy === 'use_ttl';

  return (
    <Row>
      <Col md={isSourceVisible ? 6 : 12}>
        <Container fluid className="bg-white rounded p-3">
          <Form>
            <Form.Row className="mb-2">
              <Col md={6}>
                <Form.Group controlId="interfaceName">
                  <Form.Label>Name</Form.Label>
                  <Form.Control
                    type="text"
                    placeholder="Interface name"
                    value={interfaceDraft.name}
                    onChange={handleInterfaceNameChange}
                    autoComplete="off"
                    required
                    isInvalid={interfaceValidationErrors.name != null}
                    readOnly={denyMajorChanges}
                  />
                  <Form.Control.Feedback type="invalid">
                    {interfaceValidationErrors.name}
                  </Form.Control.Feedback>
                  {interfaceValidationErrors.name == null && (
                    <FormControlWarning message={interfaceValidationWarnings.name} />
                  )}
                </Form.Group>
              </Col>
              <Col md={3}>
                <Form.Group controlId="interfaceMajor">
                  <Form.Label>Major</Form.Label>
                  <Form.Control
                    type="number"
                    min={initialData ? initialData.major : 0}
                    value={interfaceDraft.major}
                    onChange={handleInterfaceMajorChange}
                    required
                    isInvalid={interfaceValidationErrors.major != null}
                    readOnly={denyMajorChanges}
                  />
                  <Form.Control.Feedback type="invalid">
                    {interfaceValidationErrors.major}
                  </Form.Control.Feedback>
                </Form.Group>
              </Col>
              <Col md={3}>
                <Form.Group controlId="interfaceMinor">
                  <Form.Label>Minor</Form.Label>
                  <Form.Control
                    type="number"
                    min={initialData ? initialData.minor : 0}
                    value={interfaceDraft.minor}
                    onChange={handleInterfaceMinorChange}
                    required
                    isInvalid={interfaceValidationErrors.minor != null}
                  />
                  <Form.Control.Feedback type="invalid">
                    {interfaceValidationErrors.minor}
                  </Form.Control.Feedback>
                </Form.Group>
              </Col>
            </Form.Row>
            <Form.Row className="mb-2">
              <Col md={4}>
                <Form.Group>
                  <Form.Label>Type</Form.Label>
                  <Form.Check
                    type="radio"
                    name="interfaceType"
                    id="interfaceTypeDatastream"
                    label="Datastream"
                    value="datastream"
                    checked={interfaceDraft.type === 'datastream'}
                    onChange={handleInterfaceTypeChange}
                    disabled={denyMajorChanges}
                  />
                  <Form.Check
                    type="radio"
                    name="interfaceType"
                    id="interfaceTypeProperties"
                    label="Properties"
                    value="properties"
                    checked={interfaceDraft.type === 'properties'}
                    onChange={handleInterfaceTypeChange}
                    disabled={denyMajorChanges}
                  />
                </Form.Group>
              </Col>
              <Col md={4}>
                <Form.Group>
                  <Form.Label>Aggregation</Form.Label>
                  <Form.Check
                    type="radio"
                    name="interfaceAggregation"
                    id="interfaceAggregationIndividual"
                    label="Individual"
                    value="individual"
                    checked={
                      interfaceDraft.aggregation === 'individual' || !interfaceDraft.aggregation
                    }
                    onChange={handleInterfaceAggregationChange}
                    disabled={interfaceDraft.type === 'properties' || denyMajorChanges}
                  />
                  <Form.Check
                    type="radio"
                    name="interfaceAggregation"
                    id="interfaceAggregationObject"
                    label="Object"
                    value="object"
                    checked={interfaceDraft.aggregation === 'object'}
                    onChange={handleInterfaceAggregationChange}
                    disabled={interfaceDraft.type === 'properties' || denyMajorChanges}
                  />
                </Form.Group>
              </Col>
              <Col md={4}>
                <Form.Group>
                  <Form.Label>Ownership</Form.Label>
                  <Form.Check
                    type="radio"
                    name="interfaceOwnership"
                    id="interfaceOwnershipDevice"
                    label="Device"
                    value="device"
                    checked={interfaceDraft.ownership === 'device'}
                    onChange={handleInterfaceOwnershipChange}
                    disabled={denyMajorChanges}
                  />
                  <Form.Check
                    type="radio"
                    name="interfaceOwnership"
                    id="interfaceOwnershipServer"
                    label="Server"
                    value="server"
                    checked={interfaceDraft.ownership === 'server'}
                    onChange={handleInterfaceOwnershipChange}
                    disabled={denyMajorChanges}
                  />
                </Form.Group>
              </Col>
            </Form.Row>
            {interfaceDraft.type === 'datastream' && interfaceDraft.aggregation === 'object' && (
              <Form.Row className="mb-2">
                <Col md={6}>
                  <Form.Group controlId="objectMappingReliability">
                    <Form.Label>Reliability</Form.Label>
                    <Form.Control
                      as="select"
                      name="mappingReliability"
                      value={datastreamOptions.reliability || 'unreliable'}
                      onChange={handleInterfaceReliabilityChange}
                      disabled={denyMajorChanges}
                    >
                      <option value="unreliable">{reliabilityToLabel.unreliable}</option>
                      <option value="guaranteed">{reliabilityToLabel.guaranteed}</option>
                      <option value="unique">{reliabilityToLabel.unique}</option>
                    </Form.Control>
                  </Form.Group>
                </Col>
                <Col md={6}>
                  <Form.Group controlId="objectMappingExplicitTimestamp">
                    <Form.Label>Timestamp</Form.Label>
                    <Form.Check
                      type="checkbox"
                      name="mappingExplicitTimestamp"
                      label="Explicit timestamp"
                      checked={!!datastreamOptions.explicitTimestamp}
                      onChange={handleInterfaceExplicitTimestampChange}
                      disabled={denyMajorChanges}
                    />
                  </Form.Group>
                </Col>
              </Form.Row>
            )}
            {interfaceDraft.type === 'datastream' && interfaceDraft.aggregation === 'object' && (
              <Form.Row className="mb-2">
                <Col md={showInterfaceExpiry ? 6 : 12}>
                  <Form.Group controlId="objectMappingRetention">
                    <Form.Label>Retention</Form.Label>
                    <Form.Control
                      as="select"
                      name="mappingRetention"
                      value={datastreamOptions.retention || 'discard'}
                      onChange={handleInterfaceRetentionChange}
                      disabled={denyMajorChanges}
                    >
                      <option value="discard">{retentionToLabel.discard}</option>
                      <option value="volatile">{retentionToLabel.volatile}</option>
                      <option value="stored">{retentionToLabel.stored}</option>
                    </Form.Control>
                  </Form.Group>
                </Col>
                {showInterfaceExpiry && (
                  <Col md={6}>
                    <Form.Group controlId="objectMappingExpiry">
                      <Form.Label>Expiry</Form.Label>
                      <InputGroup>
                        <Form.Control
                          type="number"
                          min={0}
                          value={datastreamOptions.expiry || 0}
                          onChange={handleInterfaceExpiryChange}
                          isInvalid={(datastreamOptions.expiry || 0) < 0}
                          disabled={denyMajorChanges}
                        />
                        <InputGroup.Append>
                          <InputGroup.Text>seconds</InputGroup.Text>
                        </InputGroup.Append>
                      </InputGroup>
                    </Form.Group>
                  </Col>
                )}
              </Form.Row>
            )}
            {interfaceDraft.type === 'datastream' && interfaceDraft.aggregation === 'object' && (
              <Form.Row className="mb-2">
                <Col md={showInterfaceDatabaseRetentionTtl ? 6 : 12}>
                  <Form.Group controlId="objectMappingDatabaseRetention">
                    <Form.Label>Database Retention</Form.Label>
                    <Form.Control
                      as="select"
                      name="mappingDatabaseRetention"
                      value={datastreamOptions.databaseRetentionPolicy || 'no_ttl'}
                      onChange={handleInterfaceDatabaseRetentionPolicyChange}
                      disabled={denyMajorChanges}
                    >
                      <option value="no_ttl">{databaseRetentionToLabel.no_ttl}</option>
                      <option value="use_ttl">{databaseRetentionToLabel.use_ttl}</option>
                    </Form.Control>
                  </Form.Group>
                </Col>
                {showInterfaceDatabaseRetentionTtl && (
                  <Col md={6}>
                    <Form.Group controlId="objectMappingTTL">
                      <Form.Label>TTL</Form.Label>
                      <InputGroup>
                        <Form.Control
                          type="number"
                          min={60}
                          value={datastreamOptions.databaseRetentionTtl || 60}
                          onChange={handleInterfaceDatabaseRetentionTtlChange}
                          isInvalid={(datastreamOptions.databaseRetentionTtl || 60) < 60}
                          disabled={denyMajorChanges}
                        />
                        <InputGroup.Append>
                          <InputGroup.Text>seconds</InputGroup.Text>
                        </InputGroup.Append>
                      </InputGroup>
                    </Form.Group>
                  </Col>
                )}
              </Form.Row>
            )}
            <Form.Row className="mb-2">
              <Col sm={12}>
                <Form.Group controlId="interfaceDescription">
                  <Form.Label>Description</Form.Label>
                  <Form.Control
                    as="textarea"
                    value={interfaceDraft.description || ''}
                    onChange={handleInterfaceDescriptionChange}
                    autoComplete="off"
                    rows={3}
                    isInvalid={interfaceValidationErrors.description != null}
                  />
                  <Form.Control.Feedback type="invalid">
                    {interfaceValidationErrors.description}
                  </Form.Control.Feedback>
                </Form.Group>
              </Col>
            </Form.Row>
            <Form.Row className="mb-2">
              <Col sm={12}>
                <Form.Group controlId="interfaceDocumentation">
                  <Form.Label>Documentation</Form.Label>
                  <Form.Control
                    as="textarea"
                    value={interfaceDraft.documentation || ''}
                    onChange={handleInterfaceDocumentationChange}
                    autoComplete="off"
                    rows={3}
                    isInvalid={interfaceValidationErrors.documentation != null}
                  />
                  <Form.Control.Feedback type="invalid">
                    {interfaceValidationErrors.documentation}
                  </Form.Control.Feedback>
                </Form.Group>
              </Col>
            </Form.Row>
            <Form.Row className="mb-2">
              <Col sm={12}>
                <Form.Group controlId="interfaceMappings">
                  <button
                    type="button"
                    className="btn accordion-button w-100 mb-2"
                    onClick={handleAddMapping}
                  >
                    <i className="fas fa-plus mr-2" /> Add new mapping...
                  </button>
                  {interfaceDraft.mappings.map((mapping, index) => {
                    const isExistingMapping = (initialData?.mappings || []).some(
                      ({ endpoint }) => endpoint === mapping.endpoint,
                    );
                    const canEdit = !(denyMajorChanges && isExistingMapping);
                    const canDelete = !(denyMajorChanges && isExistingMapping);
                    return (
                      <MappingRow
                        key={mapping.endpoint}
                        className="mb-2"
                        mapping={mapping}
                        onEdit={canEdit ? () => handleEditMapping(index) : undefined}
                        onDelete={canDelete ? () => handleDeleteMapping(index) : undefined}
                      />
                    );
                  })}
                  <Form.Control
                    className="d-none"
                    isInvalid={interfaceValidationErrors.mappings != null}
                  />
                  <Form.Control.Feedback type="invalid">
                    {interfaceValidationErrors.mappings}
                  </Form.Control.Feedback>
                  <FormControlWarning message={interfaceValidationWarnings.mappings} />
                </Form.Group>
              </Col>
            </Form.Row>
          </Form>
        </Container>
      </Col>
      {isSourceVisible && (
        <Col md={6}>
          <Form.Group controlId="interfaceSource" className="h-100 d-flex flex-column">
            <Form.Control
              as="textarea"
              className="flex-grow-1 text-monospace"
              value={interfaceSource}
              onChange={handleInterfaceSourceChange}
              autoComplete="off"
              required
              isValid={isValidInterfaceSource}
              isInvalid={!isValidInterfaceSource}
            />
            <Form.Control.Feedback type="invalid">{interfaceSourceError}</Form.Control.Feedback>
          </Form.Group>
        </Col>
      )}
      {isMappingModalVisible && (
        <MappingModal
          interfaceType={interfaceDraft.type}
          interfaceAggregation={interfaceDraft.aggregation}
          mapping={mappingToEdit}
          onCancel={() => setIsMappingModalVisible(false)}
          onConfirm={handleConfirmEditMapping}
        />
      )}
    </Row>
  );
};
