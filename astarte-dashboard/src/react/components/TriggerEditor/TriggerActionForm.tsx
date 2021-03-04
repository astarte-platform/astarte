/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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

import React, { useCallback } from 'react';
import { Button, Col, Form, InputGroup, Table } from 'react-bootstrap';
import { AstarteTrigger, AstarteTriggerHTTPAction, AstarteTriggerAMQPAction } from 'astarte-client';
import _ from 'lodash';

const defaultTriggerHttpAction: AstarteTriggerHTTPAction = {
  httpUrl: '',
  httpMethod: 'post',
};

const defaultTriggerAmqpAction: AstarteTriggerAMQPAction = {
  amqpExchange: '',
  amqpMessageExpirationMilliseconds: 0,
  amqpMessagePersistent: false,
};

interface TriggerActionFormProps {
  action: AstarteTrigger['action'];
  isReadOnly?: boolean;
  onAddAmqpHeader: () => void;
  onAddHttpHeader: () => void;
  onEditAmqpHeader: (header: string) => void;
  onEditHttpHeader: (header: string) => void;
  onRemoveAmqpHeader: (header: string) => void;
  onRemoveHttpHeader: (header: string) => void;
  onChange: (action: AstarteTrigger['action']) => void;
  realm?: string | null;
  validationErrors?: { [key: string]: string };
}

const TriggerActionForm = ({
  action,
  isReadOnly,
  onAddAmqpHeader,
  onAddHttpHeader,
  onEditAmqpHeader,
  onEditHttpHeader,
  onRemoveAmqpHeader,
  onRemoveHttpHeader,
  onChange,
  realm,
  validationErrors = {},
}: TriggerActionFormProps): React.ReactElement => {
  const isHttpAction = _.get(action, 'httpUrl') != null;
  const isAmqpAction = _.get(action, 'amqpExchange') != null;
  const triggerPayloadType = _.get(action, 'templateType') || 'default';
  const triggerHttpHeaders = _.get(action, 'httpStaticHeaders') || {};
  const triggerAmqpHeaders = _.get(action, 'amqpStaticHeaders') || {};

  const handleTriggerActionTypeChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const actionType = value as 'amqp' | 'http';
      onChange(actionType === 'http' ? defaultTriggerHttpAction : defaultTriggerAmqpAction);
    },
    [onChange],
  );

  const handleTriggerActionHttpMethodChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const httpMethod = value as AstarteTriggerHTTPAction['httpMethod'];
      onChange({ ...action, httpMethod });
    },
    [action, onChange],
  );

  const handleTriggerActionHttpUrlChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const httpUrl = value as AstarteTriggerHTTPAction['httpUrl'];
      onChange({ ...action, httpUrl });
    },
    [action, onChange],
  );

  const handleTriggerActionHttpIgnoreSSLErrorsChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { checked } = e.target;
      const ignoreSslErrors = !!checked as AstarteTriggerHTTPAction['ignoreSslErrors'];
      onChange({ ...action, ignoreSslErrors });
    },
    [action, onChange],
  );

  const handleTriggerActionHttpPayloadTypeChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const payloadType = value as 'default' | 'mustache';
      if (payloadType === 'mustache') {
        onChange({ ...action, templateType: 'mustache', template: '' });
      } else {
        onChange({ ...action, templateType: undefined, template: undefined });
      }
    },
    [action, onChange],
  );

  const handleTriggerActionHttpPayloadChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const template = value;
      onChange({ ...action, template });
    },
    [action, onChange],
  );

  const handleTriggerActionAmqpExchangeChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const amqpExchange = value as AstarteTriggerAMQPAction['amqpExchange'];
      onChange({ ...action, amqpExchange });
    },
    [action, onChange],
  );

  const handleTriggerActionAmqpRoutingKeyChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const amqpRoutingKey = value as AstarteTriggerAMQPAction['amqpRoutingKey'];
      onChange({ ...action, amqpRoutingKey });
    },
    [action, onChange],
  );

  const handleTriggerActionAmqpMessagePersistentChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { checked } = e.target;
      const amqpMessagePersistent = !!checked;
      onChange({ ...action, amqpMessagePersistent });
    },
    [action, onChange],
  );

  const handleTriggerActionAmqpMessagePriorityChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const amqpMessagePriority = Number(value) as AstarteTriggerAMQPAction['amqpMessagePriority'];
      if (amqpMessagePriority === 0) {
        onChange({ ...action, amqpMessagePriority: undefined });
      } else {
        onChange({ ...action, amqpMessagePriority });
      }
    },
    [action, onChange],
  );

  const handleTriggerActionAmqpMessageExpirationMillisecondsChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const amqpMessageExpirationMilliseconds = Number(
        value,
      ) as AstarteTriggerAMQPAction['amqpMessageExpirationMilliseconds'];
      onChange({ ...action, amqpMessageExpirationMilliseconds });
    },
    [action, onChange],
  );

  return (
    <Form>
      <Form.Row className="mb-2">
        <Col sm={12}>
          <Form.Group controlId="triggerActionType">
            <Form.Label>Action type</Form.Label>
            <Form.Control
              as="select"
              name="triggerActionType"
              disabled={isReadOnly}
              value={isAmqpAction ? 'amqp' : 'http'}
              onChange={handleTriggerActionTypeChange}
            >
              <option value="http">HTTP request</option>
              <option value="amqp">AMQP Message</option>
            </Form.Control>
          </Form.Group>
        </Col>
      </Form.Row>
      {isHttpAction && (
        <>
          <Form.Row className="mb-2">
            <Col sm={4}>
              <Form.Group controlId="triggerMethod">
                <Form.Label>Method</Form.Label>
                <Form.Control
                  as="select"
                  name="triggerMethod"
                  disabled={isReadOnly}
                  value={_.get(action, 'httpMethod') || 'post'}
                  onChange={handleTriggerActionHttpMethodChange}
                  isInvalid={_.get(validationErrors, 'httpMethod') != null}
                >
                  {['delete', 'get', 'head', 'options', 'patch', 'post', 'put'].map((method) => (
                    <option key={method} value={method}>
                      {method.toUpperCase()}
                    </option>
                  ))}
                </Form.Control>
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'httpMethod')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
            <Col sm={8}>
              <Form.Group controlId="triggerUrl">
                <Form.Label>URL</Form.Label>
                <Form.Control
                  type="text"
                  autoComplete="off"
                  required
                  readOnly={isReadOnly}
                  value={_.get(action, 'httpUrl') || ''}
                  onChange={handleTriggerActionHttpUrlChange}
                  isInvalid={_.get(validationErrors, 'httpUrl') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'httpUrl')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="actionIgnoreSSLErrors">
                <Form.Check
                  type="checkbox"
                  name="actionIgnoreSSLErrors"
                  label="Ignore SSL errors"
                  disabled={isReadOnly}
                  checked={_.get(action, 'ignoreSslErrors') || false}
                  onChange={handleTriggerActionHttpIgnoreSSLErrorsChange}
                  isInvalid={_.get(validationErrors, 'ignoreSslErrors') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'ignoreSslErrors')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="triggerTemplateType">
                <Form.Label>Payload type</Form.Label>
                <Form.Control
                  as="select"
                  name="triggerTemplateType"
                  disabled={isReadOnly}
                  value={triggerPayloadType}
                  onChange={handleTriggerActionHttpPayloadTypeChange}
                >
                  <option value="default">Use default event format (JSON)</option>
                  <option value="mustache">Mustache</option>
                </Form.Control>
              </Form.Group>
            </Col>
          </Form.Row>
          {triggerPayloadType === 'mustache' && (
            <Form.Row className="mb-2">
              <Col sm={12}>
                <Form.Group controlId="actionPayload">
                  <Form.Label>Payload</Form.Label>
                  <Form.Control
                    as="textarea"
                    autoComplete="off"
                    rows={3}
                    required
                    readOnly={isReadOnly}
                    value={_.get(action, 'template') || ''}
                    onChange={handleTriggerActionHttpPayloadChange}
                    isInvalid={_.get(validationErrors, 'template') != null}
                  />
                  <Form.Control.Feedback type="invalid">
                    {_.get(validationErrors, 'template')}
                  </Form.Control.Feedback>
                </Form.Group>
              </Col>
            </Form.Row>
          )}
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="actionHttpHeaders">
                {!isReadOnly && (
                  <Button variant="link" className="p-0" onClick={() => onAddHttpHeader()}>
                    <i className="fas fa-plus mr-2" />
                    Add custom HTTP headers
                  </Button>
                )}
                {!_.isEmpty(triggerHttpHeaders) && (
                  <Table responsive>
                    <thead>
                      <tr>
                        <th>Header</th>
                        <th>Value</th>
                        {!isReadOnly && <th className="action-column">Actions</th>}
                      </tr>
                    </thead>
                    <tbody>
                      {Object.entries(triggerHttpHeaders).map(([headerName, headerValue]) => (
                        <tr key={headerName}>
                          <td>{headerName}</td>
                          <td>{headerValue as string}</td>
                          {!isReadOnly && (
                            <td className="text-center">
                              <i
                                className="fas fa-pencil-alt color-grey action-icon mr-2"
                                onClick={() => onEditHttpHeader(headerName)}
                              />
                              <i
                                className="fas fa-eraser color-red action-icon"
                                onClick={() => onRemoveHttpHeader(headerName)}
                              />
                            </td>
                          )}
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                )}
                <Form.Control
                  className="d-none"
                  isInvalid={_.get(validationErrors, 'httpStaticHeaders') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'httpStaticHeaders')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
        </>
      )}
      {isAmqpAction && (
        <>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="amqpExchange">
                <Form.Label>Exchange</Form.Label>
                <Form.Control
                  type="text"
                  autoComplete="off"
                  placeholder={`astarte_events_${realm || '<realm-name>'}_<exchange-name>`}
                  required
                  readOnly={isReadOnly}
                  value={_.get(action, 'amqpExchange') || ''}
                  onChange={handleTriggerActionAmqpExchangeChange}
                  isInvalid={_.get(validationErrors, 'amqpExchange') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'amqpExchange')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="amqpRoutingKey">
                <Form.Label>Routing key</Form.Label>
                <Form.Control
                  type="text"
                  autoComplete="off"
                  required
                  readOnly={isReadOnly}
                  value={_.get(action, 'amqpRoutingKey') || ''}
                  onChange={handleTriggerActionAmqpRoutingKeyChange}
                  isInvalid={_.get(validationErrors, 'amqpRoutingKey') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'amqpRoutingKey')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="amqpPersistency">
                <Form.Label>Persistency</Form.Label>
                <Form.Check
                  type="checkbox"
                  name="amqpPersistency"
                  label="Publish persistent messages"
                  disabled={isReadOnly}
                  checked={_.get(action, 'amqpMessagePersistent') || false}
                  onChange={handleTriggerActionAmqpMessagePersistentChange}
                  isInvalid={_.get(validationErrors, 'amqpMessagePersistent') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'amqpMessagePersistent')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="amqpPriority">
                <Form.Label>Priority</Form.Label>
                <Form.Control
                  type="number"
                  min={0}
                  max={9}
                  required
                  readOnly={isReadOnly}
                  value={_.get(action, 'amqpMessagePriority') || 0}
                  onChange={handleTriggerActionAmqpMessagePriorityChange}
                  isInvalid={_.get(validationErrors, 'amqpMessagePriority') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'amqpMessagePriority')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="amqpExpiration">
                <Form.Label>Expiration</Form.Label>
                <InputGroup>
                  <Form.Control
                    type="number"
                    min={1}
                    required
                    readOnly={isReadOnly}
                    value={_.get(action, 'amqpMessageExpirationMilliseconds') || 0}
                    onChange={handleTriggerActionAmqpMessageExpirationMillisecondsChange}
                    isInvalid={_.get(validationErrors, 'amqpMessageExpirationMilliseconds') != null}
                  />
                  <InputGroup.Append>
                    <InputGroup.Text>milliseconds</InputGroup.Text>
                  </InputGroup.Append>
                  <Form.Control.Feedback type="invalid">
                    {_.get(validationErrors, 'amqpMessageExpirationMilliseconds')}
                  </Form.Control.Feedback>
                </InputGroup>
              </Form.Group>
            </Col>
          </Form.Row>
          <Form.Row className="mb-2">
            <Col sm={12}>
              <Form.Group controlId="actionAmqpHeaders">
                {!isReadOnly && (
                  <Button variant="link" className="p-0" onClick={() => onAddAmqpHeader()}>
                    <i className="fas fa-plus mr-2" />
                    Add static AMQP headers
                  </Button>
                )}
                {!_.isEmpty(triggerAmqpHeaders) && (
                  <Table responsive>
                    <thead>
                      <tr>
                        <th>Header</th>
                        <th>Value</th>
                        {!isReadOnly && <th className="action-column">Actions</th>}
                      </tr>
                    </thead>
                    <tbody>
                      {Object.entries(triggerAmqpHeaders).map(([headerName, headerValue]) => (
                        <tr key={headerName}>
                          <td>{headerName}</td>
                          <td>{headerValue as string}</td>
                          {!isReadOnly && (
                            <td className="text-center">
                              <i
                                className="fas fa-pencil-alt color-grey action-icon mr-2"
                                onClick={() => onEditAmqpHeader(headerName)}
                              />
                              <i
                                className="fas fa-eraser color-red action-icon"
                                onClick={() => onRemoveAmqpHeader(headerName)}
                              />
                            </td>
                          )}
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                )}
                <Form.Control
                  className="d-none"
                  isInvalid={_.get(validationErrors, 'amqpStaticHeaders') != null}
                />
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'amqpStaticHeaders')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
          </Form.Row>
        </>
      )}
    </Form>
  );
};

export default TriggerActionForm;
