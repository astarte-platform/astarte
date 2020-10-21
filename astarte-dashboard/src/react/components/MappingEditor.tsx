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
import { Col, Form, InputGroup } from 'react-bootstrap';
import { AstarteMapping } from 'astarte-client';
import type { AstarteInterface } from 'astarte-client';
import _ from 'lodash';

const astarteDataTypes: AstarteMapping['type'][] = [
  'string',
  'boolean',
  'double',
  'integer',
  'longinteger',
  'binaryblob',
  'datetime',
  'doublearray',
  'integerarray',
  'booleanarray',
  'longintegerarray',
  'stringarray',
  'binaryblobarray',
  'datetimearray',
];

const defaultMapping: AstarteMapping = {
  endpoint: '',
  type: 'double',
};

interface Props {
  interfaceType: AstarteInterface['type'];
  interfaceAggregation?: AstarteInterface['aggregation'];
  mapping?: AstarteMapping;
  onChange: (updatedMapping: AstarteMapping) => unknown;
}

export default ({
  interfaceType,
  interfaceAggregation = 'individual',
  mapping = defaultMapping,
  onChange,
}: Props): React.ReactElement => {
  const isPropertiesInterface = interfaceType === 'properties';
  const isDatastreamIndividualInterface =
    interfaceType === 'datastream' && interfaceAggregation === 'individual';
  const showMappingExpiry = mapping.retention === 'volatile' || mapping.retention === 'stored';
  const showInterfaceDatabaseRetentionTtl = mapping.databaseRetentionPolicy === 'use_ttl';

  let mappingValidationErrors: { [property: string]: string } = {};
  try {
    AstarteMapping.validation.validateSync(mapping, { abortEarly: false });
  } catch (err) {
    mappingValidationErrors = _.mapValues(_.keyBy(_.uniqBy(err.inner, 'path'), 'path'), 'message');
  }

  return (
    <Form>
      <Form.Row className="mb-2">
        <Col sm={12}>
          <Form.Group controlId="mappingEndpoint">
            <Form.Label>Endpoint</Form.Label>
            <Form.Control
              type="text"
              value={mapping.endpoint}
              onChange={({ target: { value } }) => onChange({ ...mapping, endpoint: value })}
              autoComplete="off"
              required
              isInvalid={mappingValidationErrors.endpoint != null}
            />
            <Form.Control.Feedback type="invalid">
              {mappingValidationErrors.endpoint}
            </Form.Control.Feedback>
          </Form.Group>
        </Col>
      </Form.Row>
      <Form.Row className="mb-2">
        <Col sm={isPropertiesInterface ? 8 : 12}>
          <Form.Group controlId="mappingType">
            <Form.Label>Type</Form.Label>
            <Form.Control
              as="select"
              value={mapping.type}
              onChange={({ target: { value } }) =>
                onChange({ ...mapping, type: value as AstarteMapping['type'] })
              }
              isInvalid={mappingValidationErrors.type != null}
            >
              {astarteDataTypes.map((t) => (
                <option key={t}>{t}</option>
              ))}
            </Form.Control>
            <Form.Control.Feedback type="invalid">
              {mappingValidationErrors.type}
            </Form.Control.Feedback>
          </Form.Group>
        </Col>
        {isPropertiesInterface && (
          <Col sm={4}>
            <Form.Group controlId="mappingAllowUnset">
              <Form.Label>Property options</Form.Label>
              <Form.Check
                type="checkbox"
                label="Allow unset"
                checked={!!mapping.allowUnset}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => {
                  const allowUnset = !!e.target.checked;
                  onChange({ ...mapping, allowUnset: allowUnset || undefined });
                }}
                isInvalid={mappingValidationErrors.allowUnset != null}
              />
              <Form.Control.Feedback type="invalid">
                {mappingValidationErrors.allowUnset}
              </Form.Control.Feedback>
            </Form.Group>
          </Col>
        )}
      </Form.Row>
      {isDatastreamIndividualInterface && (
        <Form.Row className="mb-2">
          <Col md={6}>
            <Form.Group controlId="mappingReliability">
              <Form.Label>Reliability</Form.Label>
              <Form.Control
                as="select"
                name="reliability"
                value={mapping.reliability || 'unreliable'}
                onChange={({ currentTarget: { value } }) => {
                  let reliability = value as AstarteMapping['reliability'];
                  reliability = reliability === 'unreliable' ? undefined : reliability;
                  onChange({ ...mapping, reliability });
                }}
                isInvalid={mappingValidationErrors.reliability != null}
              >
                <option value="unreliable">Unreliable</option>
                <option value="guaranteed">Guaranteed</option>
                <option value="unique">Unique</option>
              </Form.Control>
              <Form.Control.Feedback type="invalid">
                {mappingValidationErrors.reliability}
              </Form.Control.Feedback>
            </Form.Group>
          </Col>
          <Col sm={6}>
            <Form.Group controlId="mappingExplicitTimestamp">
              <Form.Label>Timestamp</Form.Label>
              <Form.Check
                type="checkbox"
                label="Explicit timestamp"
                checked={!!mapping.explicitTimestamp}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => {
                  const explicitTimestamp = !!e.target.checked;
                  onChange({ ...mapping, explicitTimestamp: explicitTimestamp || undefined });
                }}
                isInvalid={mappingValidationErrors.explicitTimestamp != null}
              />
              <Form.Control.Feedback type="invalid">
                {mappingValidationErrors.explicitTimestamp}
              </Form.Control.Feedback>
            </Form.Group>
          </Col>
        </Form.Row>
      )}
      {isDatastreamIndividualInterface && (
        <Form.Row className="mb-2">
          <Col md={showMappingExpiry ? 6 : 12}>
            <Form.Group controlId="mappingRetention">
              <Form.Label>Retention</Form.Label>
              <Form.Control
                as="select"
                name="retention"
                value={mapping.retention || 'discard'}
                onChange={({ currentTarget: { value } }) => {
                  const retention = value as AstarteMapping['retention'];
                  onChange({
                    ...mapping,
                    retention: retention === 'discard' ? undefined : retention,
                    expiry: retention === 'discard' ? undefined : mapping.expiry,
                  });
                }}
                isInvalid={mappingValidationErrors.retention != null}
              >
                <option value="discard">Discard</option>
                <option value="volatile">Volatile</option>
                <option value="stored">Stored</option>
              </Form.Control>
              <Form.Control.Feedback type="invalid">
                {mappingValidationErrors.retention}
              </Form.Control.Feedback>
            </Form.Group>
          </Col>
          {showMappingExpiry && (
            <Col md={6}>
              <Form.Group controlId="mappingExpiry">
                <Form.Label>Expiry</Form.Label>
                <InputGroup>
                  <Form.Control
                    type="number"
                    min={0}
                    value={mapping.expiry || 0}
                    onChange={({ currentTarget: { value } }) => {
                      const expiry = parseInt(value, 10) || undefined;
                      onChange({ ...mapping, expiry });
                    }}
                    isInvalid={mappingValidationErrors.expiry != null}
                  />
                  <InputGroup.Append>
                    <InputGroup.Text>seconds</InputGroup.Text>
                  </InputGroup.Append>
                  <Form.Control.Feedback type="invalid">
                    {mappingValidationErrors.expiry}
                  </Form.Control.Feedback>
                </InputGroup>
              </Form.Group>
            </Col>
          )}
        </Form.Row>
      )}
      {isDatastreamIndividualInterface && (
        <Form.Row className="mb-2">
          <Col md={showInterfaceDatabaseRetentionTtl ? 6 : 12}>
            <Form.Group controlId="mappingDatabaseRetention">
              <Form.Label>Database retention</Form.Label>
              <Form.Control
                as="select"
                name="mappingDatabaseRetention"
                value={mapping.databaseRetentionPolicy || 'no_ttl'}
                onChange={({ currentTarget: { value } }) => {
                  const databaseRetentionPolicy = value as AstarteMapping['databaseRetentionPolicy'];
                  onChange({
                    ...mapping,
                    databaseRetentionPolicy:
                      databaseRetentionPolicy === 'no_ttl' ? undefined : databaseRetentionPolicy,
                    databaseRetentionTtl:
                      databaseRetentionPolicy === 'no_ttl'
                        ? undefined
                        : mapping.databaseRetentionTtl || 60,
                  });
                }}
                isInvalid={mappingValidationErrors.databaseRetentionPolicy != null}
              >
                <option value="no_ttl">No TTL</option>
                <option value="use_ttl">Use TTL</option>
              </Form.Control>
              <Form.Control.Feedback type="invalid">
                {mappingValidationErrors.databaseRetentionPolicy}
              </Form.Control.Feedback>
            </Form.Group>
          </Col>
          {showInterfaceDatabaseRetentionTtl && (
            <Col md={6}>
              <Form.Group controlId="mappingTTL">
                <Form.Label>TTL</Form.Label>
                <InputGroup>
                  <Form.Control
                    type="number"
                    min={60}
                    value={mapping.databaseRetentionTtl || 60}
                    onChange={({ currentTarget: { value } }) => {
                      const databaseRetentionTtl = parseInt(value, 10);
                      onChange({ ...mapping, databaseRetentionTtl });
                    }}
                    isInvalid={mappingValidationErrors.databaseRetentionTtl != null}
                  />
                  <InputGroup.Append>
                    <InputGroup.Text>seconds</InputGroup.Text>
                  </InputGroup.Append>
                  <Form.Control.Feedback type="invalid">
                    {mappingValidationErrors.databaseRetentionTtl}
                  </Form.Control.Feedback>
                </InputGroup>
              </Form.Group>
            </Col>
          )}
        </Form.Row>
      )}
      <Form.Row className="mb-2">
        <Col sm={12}>
          <Form.Group controlId="mappingDescription">
            <Form.Label>Description</Form.Label>
            <Form.Control
              as="textarea"
              value={mapping.description || ''}
              onChange={({ target: { value } }) =>
                onChange({ ...mapping, description: value || undefined })
              }
              autoComplete="off"
              isInvalid={mappingValidationErrors.description != null}
            />
            <Form.Control.Feedback type="invalid">
              {mappingValidationErrors.description}
            </Form.Control.Feedback>
          </Form.Group>
        </Col>
      </Form.Row>
      <Form.Row className="mb-2">
        <Col sm={12}>
          <Form.Group controlId="mappingDocumentation">
            <Form.Label>Documentation</Form.Label>
            <Form.Control
              as="textarea"
              value={mapping.documentation || ''}
              onChange={({ target: { value } }) =>
                onChange({ ...mapping, documentation: value || undefined })
              }
              autoComplete="off"
              isInvalid={mappingValidationErrors.documentation != null}
            />
            <Form.Control.Feedback type="invalid">
              {mappingValidationErrors.documentation}
            </Form.Control.Feedback>
          </Form.Group>
        </Col>
      </Form.Row>
    </Form>
  );
};
