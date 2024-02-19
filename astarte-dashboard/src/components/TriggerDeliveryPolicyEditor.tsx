/*
This file is part of Astarte.

Copyright 2023 SECO Mind Srl

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
/* eslint-disable camelcase */

import React, { useCallback, useEffect, useState } from 'react';
import { Col, Container, Form, InputGroup, Row } from 'react-bootstrap';
import _, { toInteger } from 'lodash';
import { AstarteTriggerDeliveryPolicyDTO } from 'astarte-client/types/dto';
import * as yup from 'yup';
import { AstarteTriggerDeliveryPolicy } from 'astarte-client/models/Policy';
import TriggerDeliveryPolicyHandler from './TriggerDeliveryPolicyHandler';

const validateName = (name: string) => {
  const regex = /^(?!@).{1,128}$/;
  return regex.test(name);
};

const checkValidJSONText = (text: string): boolean => {
  try {
    JSON.parse(text);
    return true;
  } catch {
    return false;
  }
};

const defaultPolicy: AstarteTriggerDeliveryPolicyDTO = {
  name: '',
  error_handlers: [],
  maximum_capacity: 100,
};

interface Props {
  initialData?: AstarteTriggerDeliveryPolicyDTO;
  isReadOnly: boolean;
  isSourceVisible?: boolean;
  onChange?: (updatedPolicy: AstarteTriggerDeliveryPolicyDTO, isValid: boolean) => unknown;
}

export default ({
  initialData,
  isReadOnly,
  isSourceVisible,
  onChange,
}: Props): React.ReactElement => {
  const [policyDraft, setPolicyDraft] = useState<AstarteTriggerDeliveryPolicy>(
    initialData || defaultPolicy,
  );
  const [policySource, setPolicySource] = useState(JSON.stringify(policyDraft, null, 4));
  const [policySourceError, setPolicySourceError] = useState('');
  const [isValidPolicySource, setIsValidPolicySource] = useState(true);
  const isRetryTimesDisabled = !policyDraft.error_handlers.some((e) => e.strategy === 'retry');

  const handlePolicyNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setPolicyDraft((draft) => ({ ...draft, name: value }));
  };

  const handlePolicyCapacityChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setPolicyDraft((draft) => ({ ...draft, maximum_capacity: toInteger(value) }));
  }, []);

  const handleRetryChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    if (toInteger(value) >= 1) {
      setPolicyDraft((draft) => ({ ...draft, retry_times: toInteger(value) }));
    } else {
      setPolicyDraft((draft) => {
        const { retry_times, ...restElements } = draft;
        return restElements;
      });
    }
  }, []);

  const handleEventTtlChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    if (toInteger(value) >= 1) {
      setPolicyDraft((draft) => ({ ...draft, event_ttl: toInteger(value) }));
    } else {
      setPolicyDraft((draft) => {
        const { event_ttl, ...restElements } = draft;
        return restElements;
      });
    }
  }, []);

  const setErrorMessage = (message: string) => {
    setPolicySourceError(message);
    setIsValidPolicySource(false);
  };

  const isValidJSON = (policy: AstarteTriggerDeliveryPolicyDTO) => {
    try {
      AstarteTriggerDeliveryPolicy.validation.validateSync(policy, { abortEarly: false });
      setIsValidPolicySource(true);
    } catch (error) {
      setIsValidPolicySource(false);
      if (error) {
        if (error instanceof yup.ValidationError) {
          setErrorMessage(error.inner[0].message);
        }
      }
    }
  };

  const validJSONText = (value: string) => {
    if (!checkValidJSONText(value)) {
      setErrorMessage('Invalid JSON!');
      return;
    }
    const newPolicy: AstarteTriggerDeliveryPolicyDTO = JSON.parse(value);
    isValidJSON(newPolicy);
  };

  const handlePolicyChange = useCallback((updatedPolicy: AstarteTriggerDeliveryPolicyDTO) => {
    const isStrategyFieldRetry = updatedPolicy.error_handlers.some((e) => e.strategy === 'retry');
    const newPolicy: AstarteTriggerDeliveryPolicyDTO = updatedPolicy;
    if (
      isStrategyFieldRetry &&
      (updatedPolicy.retry_times === undefined || updatedPolicy.retry_times === 0)
    ) {
      newPolicy.retry_times = 1;
    }
    if (!isStrategyFieldRetry) {
      const { retry_times, ...restElements } = newPolicy;
      setPolicyDraft(restElements);
      return;
    }
    setPolicyDraft(newPolicy);
    setPolicySource(JSON.stringify(newPolicy, null, 4));
    isValidJSON(newPolicy);
  }, []);

  const handlePolicySourceChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setPolicySource(value);
    validJSONText(value);
    if (checkValidJSONText(value)) {
      handlePolicyChange(JSON.parse(value));
    }
  };

  useEffect(() => {
    setPolicySource(JSON.stringify(policyDraft, null, 4));
    isValidJSON(policyDraft);
  }, [policyDraft]);

  useEffect(() => {
    if (onChange) {
      onChange(policyDraft, isValidPolicySource);
    }
  }, [isValidPolicySource, onChange, policyDraft]);

  return (
    <Row>
      <Col md={isSourceVisible ? 6 : 12}>
        <Container fluid className="bg-white rounded p-3">
          <Form>
            <Form.Row className="mb-2">
              <Col sm={12}>
                <Form.Group controlId="policyName">
                  <Form.Label>Name</Form.Label>
                  <Form.Control
                    type="text"
                    autoComplete="off"
                    required
                    readOnly={isReadOnly}
                    value={_.get(policyDraft, 'name')}
                    onChange={handlePolicyNameChange}
                    isInvalid={!validateName(policyDraft.name)}
                    spellCheck={false}
                  />
                  <Form.Control.Feedback type="invalid">
                    name is a required field
                  </Form.Control.Feedback>
                </Form.Group>
                <Form.Group controlId="policyHandler">
                  <TriggerDeliveryPolicyHandler
                    onChange={handlePolicyChange}
                    initialData={policyDraft}
                    isReadOnly={isReadOnly}
                  />
                </Form.Group>
                <Form.Group controlId="policyRetryTimes">
                  <Form.Label>Retry Times</Form.Label>
                  <Form.Control
                    type="number"
                    autoComplete="off"
                    required
                    min={!isRetryTimesDisabled ? 1 : 0}
                    readOnly={isReadOnly}
                    disabled={isRetryTimesDisabled}
                    value={_.get(policyDraft, 'retry_times') || 0}
                    onChange={handleRetryChange}
                  />
                </Form.Group>
                <Form.Group controlId="policyCapacity">
                  <Form.Label>Maximum Capacity</Form.Label>
                  <Form.Control
                    type="number"
                    autoComplete="off"
                    required
                    min="1"
                    readOnly={isReadOnly}
                    value={_.get(policyDraft, 'maximum_capacity')}
                    onChange={handlePolicyCapacityChange}
                    isInvalid={_.get(policyDraft, 'maximum_capacity') < 0}
                  />
                  <Form.Control.Feedback type="invalid">
                    maximum_capacity must be greater than 0
                  </Form.Control.Feedback>
                </Form.Group>
                <Form.Group controlId="policyEventTTL">
                  <Form.Label>Event TTL</Form.Label>
                  <InputGroup>
                    <Form.Control
                      type="number"
                      autoComplete="off"
                      required
                      min="0"
                      readOnly={isReadOnly}
                      value={_.get(policyDraft, 'event_ttl') || 0}
                      onChange={handleEventTtlChange}
                    />
                    <InputGroup.Append>
                      <InputGroup.Text>seconds</InputGroup.Text>
                    </InputGroup.Append>
                  </InputGroup>
                </Form.Group>
              </Col>
            </Form.Row>
          </Form>
        </Container>
      </Col>
      {isSourceVisible && (
        <Col md={6}>
          <Form.Group controlId="policySource" className="h-100 d-flex flex-column">
            <Form.Control
              as="textarea"
              className="flex-grow-1 font-monospace"
              value={policySource}
              onChange={handlePolicySourceChange}
              autoComplete="off"
              required
              readOnly={isReadOnly}
              isValid={isValidPolicySource}
              isInvalid={!isValidPolicySource}
              spellCheck={false}
            />
            <Form.Control.Feedback type="invalid">{policySourceError}</Form.Control.Feedback>
          </Form.Group>
        </Col>
      )}
    </Row>
  );
};
