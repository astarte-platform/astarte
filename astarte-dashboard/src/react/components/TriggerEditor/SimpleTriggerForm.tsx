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

import React, { useCallback, useMemo } from 'react';
import { Col, Form } from 'react-bootstrap';
import {
  AstarteInterface,
  AstarteMapping,
  AstarteSimpleTrigger,
  AstarteSimpleDeviceTrigger,
  AstarteSimpleDataTrigger,
} from 'astarte-client';
import _ from 'lodash';

const triggerConditionToLabel = {
  device_disconnected: 'Device Disconnected',
  device_connected: 'Device Connected',
  device_error: 'Device Error',
  device_empty_cache_received: 'Empty Cache Received',
  incoming_data: 'Incoming Data',
  value_change: 'Value Change',
  value_change_applied: 'Value Change Applied',
  path_created: 'Path Created',
  path_removed: 'Path Removed',
  value_stored: 'Value Stored',
};

const triggerOperatorToLabel = {
  '*': '*',
  '==': '==',
  '!=': '!=',
  '>': '>',
  '>=': '>=',
  '<': '<',
  '<=': '<=',
  contains: 'Contains',
  not_contains: 'Not Contains',
};

const defaultSimpleDeviceTrigger: AstarteSimpleDeviceTrigger = {
  type: 'device_trigger',
  on: 'device_connected',
};

const defaultSimpleDataTrigger: AstarteSimpleDataTrigger = {
  type: 'data_trigger',
  on: 'incoming_data',
  interfaceName: '*',
  matchPath: '/*',
  valueMatchOperator: '*',
};

interface SimpleTriggerFormProps {
  fetchInterface: (params: {
    interfaceName: string;
    interfaceMajor: number;
  }) => Promise<AstarteInterface | null>;
  fetchInterfaceMajors: (interfaceName: string) => Promise<number[]>;
  interfacesName: string[];
  interfaceMajors: number[];
  isLoadingInterface?: boolean;
  isLoadingInterfacesName?: boolean;
  isLoadingInterfaceMajors?: boolean;
  isReadOnly?: boolean;
  onChange: (simpleTrigger: AstarteSimpleTrigger) => void;
  simpleTrigger: AstarteSimpleTrigger;
  simpleTriggerInterface: AstarteInterface | null;
  validationErrors?: { [key: string]: string };
}

const SimpleTriggerForm = ({
  fetchInterface,
  fetchInterfaceMajors,
  interfacesName = [],
  interfaceMajors = [],
  isLoadingInterface = false,
  isLoadingInterfacesName = false,
  isLoadingInterfaceMajors = false,
  isReadOnly,
  onChange,
  simpleTrigger,
  simpleTriggerInterface,
  validationErrors = {},
}: SimpleTriggerFormProps): React.ReactElement => {
  const isDeviceTrigger = _.get(simpleTrigger, 'type') === 'device_trigger';
  const isDataTrigger = _.get(simpleTrigger, 'type') === 'data_trigger';
  const hasTargetDevice = _.get(simpleTrigger, 'deviceId') != null;
  const hasTargetGroup = _.get(simpleTrigger, 'groupName') != null;
  // eslint-disable-next-line no-nested-ternary
  const triggerTargetType = hasTargetDevice ? 'device' : hasTargetGroup ? 'group' : 'all_devices';
  const triggerInterfaceName: string | undefined = _.get(simpleTrigger, 'interfaceName');
  const hasSelectedInterface = triggerInterfaceName != null && triggerInterfaceName !== '*';
  const triggerValueMatchOperator:
    | AstarteSimpleDataTrigger['valueMatchOperator']
    | undefined = _.get(simpleTrigger, 'valueMatchOperator');
  const hasSelectedOperator =
    triggerValueMatchOperator != null && triggerValueMatchOperator !== '*';
  const triggerMatchPath: AstarteSimpleDataTrigger['matchPath'] | undefined = _.get(
    simpleTrigger,
    'matchPath',
  );
  const triggerInterfaceType = useMemo(
    () => (simpleTriggerInterface ? simpleTriggerInterface.type : null),
    [simpleTriggerInterface],
  );
  const triggerInterfaceAggregation = useMemo(
    () => (simpleTriggerInterface ? simpleTriggerInterface.aggregation : null),
    [simpleTriggerInterface],
  );
  const triggerInterfacePathType = useMemo(() => {
    if (!simpleTriggerInterface || !triggerMatchPath) {
      return null;
    }
    const mapping = simpleTriggerInterface.mappings.find((m) =>
      AstarteMapping.matchEndpoint(m.endpoint, triggerMatchPath),
    );
    return mapping ? mapping.type : null;
  }, [simpleTriggerInterface, triggerMatchPath]);

  const handleTriggerTypeChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.currentTarget;
      const type = value as AstarteSimpleTrigger['type'];
      onChange(type === 'data_trigger' ? defaultSimpleDataTrigger : defaultSimpleDeviceTrigger);
    },
    [onChange],
  );

  const handleTriggerConditionChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.currentTarget;
      const on = value as AstarteSimpleTrigger['on'];
      onChange({ ...simpleTrigger, on } as AstarteSimpleTrigger);
    },
    [simpleTrigger, onChange],
  );

  const handleTriggerTargetChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.currentTarget;
      const target = value as 'all_devices' | 'device' | 'group';
      if (target === 'device') {
        onChange({ ...simpleTrigger, deviceId: '', groupName: undefined });
      } else if (target === 'group') {
        onChange({ ...simpleTrigger, deviceId: undefined, groupName: '' });
      } else {
        onChange({ ...simpleTrigger, deviceId: undefined, groupName: undefined });
      }
    },
    [simpleTrigger, onChange],
  );

  const handleTriggerTargetDeviceChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      onChange({ ...simpleTrigger, deviceId: value });
    },
    [simpleTrigger, onChange],
  );

  const handleTriggerTargetGroupChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      onChange({ ...simpleTrigger, groupName: value });
    },
    [simpleTrigger, onChange],
  );

  const handleTriggerInterfaceNameChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const interfaceName = value;
      const newSimpleTrigger = {
        ...simpleTrigger,
        interfaceName,
        interfaceMajor: undefined,
        matchPath: '/*',
        valueMatchOperator: '*',
        knownValue: undefined,
      } as AstarteSimpleDataTrigger;
      onChange(newSimpleTrigger);
      if (interfaceName !== '*') {
        fetchInterfaceMajors(interfaceName).then((majors) => {
          if (majors.length > 0) {
            const interfaceMajor = Math.max(...majors);
            onChange({ ...newSimpleTrigger, interfaceMajor });
            fetchInterface({ interfaceName, interfaceMajor });
          }
        });
      }
    },
    [simpleTrigger, onChange, fetchInterfaceMajors, fetchInterface],
  );

  const handleTriggerInterfaceMajorChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const interfaceMajor = parseInt(value, 10);
      onChange({
        ...simpleTrigger,
        interfaceMajor,
        matchPath: '/*',
        valueMatchOperator: '*',
        knownValue: undefined,
      } as AstarteSimpleDataTrigger);
      const interfaceName = triggerInterfaceName as string;
      fetchInterface({ interfaceName, interfaceMajor });
    },
    [simpleTrigger, onChange, fetchInterface, triggerInterfaceName],
  );

  const handleTriggerInterfacePathChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const matchPath = value;
      onChange({
        ...simpleTrigger,
        matchPath,
        valueMatchOperator: '*',
        knownValue: undefined,
      } as AstarteSimpleDataTrigger);
    },
    [simpleTrigger, onChange],
  );

  const handleTriggerInterfaceOperatorChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      const valueMatchOperator = value as AstarteSimpleDataTrigger['valueMatchOperator'];
      if (valueMatchOperator === '*') {
        onChange({
          ...simpleTrigger,
          valueMatchOperator,
          knownValue: undefined,
        } as AstarteSimpleDataTrigger);
      } else {
        onChange({
          ...simpleTrigger,
          valueMatchOperator,
        } as AstarteSimpleDataTrigger);
      }
    },
    [simpleTrigger, onChange],
  );

  const handleTriggerInterfaceKnownValueChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { value } = e.target;
      let knownValue: AstarteSimpleDataTrigger['knownValue'] = value;
      if (!triggerInterfacePathType) {
        knownValue = String(value);
      } else if (['boolean', 'booleanarray'].includes(triggerInterfacePathType)) {
        if (value.toLowerCase() === 'false') {
          knownValue = false;
        }
        if (value.toLowerCase() === 'true') {
          knownValue = true;
        }
      } else if (
        ['integer', 'double', 'integerarray', 'doublearray'].includes(triggerInterfacePathType)
      ) {
        const parsedValue = parseFloat(value);
        if (!Number.isNaN(parsedValue)) {
          knownValue = parsedValue;
        }
      }
      onChange({ ...simpleTrigger, knownValue } as AstarteSimpleDataTrigger);
    },
    [simpleTrigger, onChange, triggerInterfacePathType],
  );

  const renderTriggerConditionOptions = useCallback(() => {
    let options: Array<keyof typeof triggerConditionToLabel> = [];
    if (isDeviceTrigger) {
      options = [
        'device_connected',
        'device_disconnected',
        'device_error',
        'device_empty_cache_received',
      ];
    } else if (triggerInterfaceType === 'properties') {
      options = [
        'incoming_data',
        'value_change',
        'value_change_applied',
        'path_created',
        'path_removed',
        'value_stored',
      ];
    } else {
      // TODO: this is a workaround to for the issue https://github.com/astarte-platform/astarte/issues/523
      options =
        triggerInterfaceAggregation === 'object'
          ? ['incoming_data']
          : ['incoming_data', 'value_stored'];
    }
    return options.map((option) => (
      <option key={option} value={option}>
        {triggerConditionToLabel[option]}
      </option>
    ));
  }, [isDeviceTrigger, triggerInterfaceType]);

  const renderInterfaceNameOptions = useCallback(() => {
    const options = interfacesName.map((ifaceName) => (
      <option key={ifaceName} value={ifaceName}>
        {ifaceName}
      </option>
    ));
    return [
      <option key="*" value="*">
        Any interface
      </option>,
      ...options,
    ];
  }, [interfacesName]);

  const renderInterfaceMajorOptions = useCallback(() => {
    const options = interfaceMajors.map((ifaceMajor) => (
      <option key={ifaceMajor} value={ifaceMajor}>
        {ifaceMajor}
      </option>
    ));
    return options;
  }, [interfaceMajors]);

  const renderTriggerOperatorOptions = useCallback(() => {
    let operators: Array<keyof typeof triggerOperatorToLabel> = [];
    if (!triggerInterfacePathType) {
      operators = ['*'];
    } else {
      const isArrayLikePath =
        triggerInterfacePathType.includes('array') ||
        triggerInterfacePathType.includes('string') ||
        triggerInterfacePathType.includes('binaryblob');
      operators = isArrayLikePath
        ? ['*', '==', '!=', '>', '>=', '<', '<=', 'contains', 'not_contains']
        : ['*', '==', '!=', '>', '>=', '<', '<='];
    }
    const options = operators.map((operator) => (
      <option key={operator} value={operator}>
        {triggerOperatorToLabel[operator]}
      </option>
    ));
    return options;
  }, [triggerInterfacePathType]);

  return (
    <Form>
      <Form.Row className="mb-2">
        <Col sm={12}>
          <Form.Group controlId="triggerSimpleTriggerType">
            <Form.Label>Trigger type</Form.Label>
            <Form.Control
              as="select"
              name="triggerSimpleTriggerType"
              disabled={isReadOnly}
              value={_.get(simpleTrigger, 'type')}
              onChange={handleTriggerTypeChange}
              isInvalid={_.get(validationErrors, 'type') != null}
            >
              <option value="device_trigger">Device Trigger</option>
              <option value="data_trigger">Data Trigger</option>
            </Form.Control>
            <Form.Control.Feedback type="invalid">
              {_.get(validationErrors, 'type')}
            </Form.Control.Feedback>
          </Form.Group>
        </Col>
      </Form.Row>
      <Form.Row className="mb-2">
        <Col sm={hasTargetDevice || hasTargetGroup ? 4 : 12}>
          <Form.Group controlId="triggerTargetSelect">
            <Form.Label>Target</Form.Label>
            <Form.Control
              as="select"
              name="triggerTargetSelect"
              disabled={isReadOnly}
              value={triggerTargetType}
              onChange={handleTriggerTargetChange}
            >
              <option value="all_devices">All devices</option>
              <option value="device">Device</option>
              <option value="group">Group</option>
            </Form.Control>
          </Form.Group>
        </Col>
        {hasTargetDevice && (
          <Col sm={8}>
            <Form.Group controlId="triggerDeviceId">
              <Form.Label>Device id</Form.Label>
              <Form.Control
                type="text"
                autoComplete="off"
                required
                readOnly={isReadOnly}
                value={_.get(simpleTrigger, 'deviceId') || ''}
                onChange={handleTriggerTargetDeviceChange}
                isInvalid={_.get(validationErrors, 'deviceId') != null}
              />
              <Form.Control.Feedback type="invalid">
                {_.get(validationErrors, 'deviceId')}
              </Form.Control.Feedback>
            </Form.Group>
          </Col>
        )}
        {hasTargetGroup && (
          <Col sm={8}>
            <Form.Group controlId="triggerGroupName">
              <Form.Label>Group Name</Form.Label>
              <Form.Control
                type="text"
                autoComplete="off"
                required
                readOnly={isReadOnly}
                value={_.get(simpleTrigger, 'groupName') || ''}
                onChange={handleTriggerTargetGroupChange}
                isInvalid={_.get(validationErrors, 'groupName') != null}
              />
              <Form.Control.Feedback type="invalid">
                {_.get(validationErrors, 'groupName')}
              </Form.Control.Feedback>
            </Form.Group>
          </Col>
        )}
      </Form.Row>
      <Form.Row className="mb-2">
        <Col sm={12}>
          <Form.Group controlId="triggerCondition">
            <Form.Label>Trigger condition</Form.Label>
            <Form.Control
              as="select"
              name="triggerCondition"
              disabled={isReadOnly || isLoadingInterface}
              value={_.get(simpleTrigger, 'on')}
              onChange={handleTriggerConditionChange}
              isInvalid={_.get(validationErrors, 'on') != null}
            >
              {renderTriggerConditionOptions()}
            </Form.Control>
            <Form.Control.Feedback type="invalid">
              {_.get(validationErrors, 'on')}
            </Form.Control.Feedback>
          </Form.Group>
        </Col>
      </Form.Row>
      {isDataTrigger && (
        <>
          <Form.Row className="mb-2">
            <Col sm={hasSelectedInterface ? 8 : 12}>
              <Form.Group controlId="triggerInterfaceName">
                <Form.Label>Interface name</Form.Label>
                <Form.Control
                  as="select"
                  name="triggerInterfaceName"
                  disabled={isReadOnly || isLoadingInterfacesName}
                  value={triggerInterfaceName || '*'}
                  onChange={handleTriggerInterfaceNameChange}
                  isInvalid={_.get(validationErrors, 'interfaceName') != null}
                >
                  {renderInterfaceNameOptions()}
                </Form.Control>
                <Form.Control.Feedback type="invalid">
                  {_.get(validationErrors, 'interfaceName')}
                </Form.Control.Feedback>
              </Form.Group>
            </Col>
            {hasSelectedInterface && (
              <Col sm={4}>
                <Form.Group controlId="triggerInterfaceMajor">
                  <Form.Label>Interface major</Form.Label>
                  <Form.Control
                    as="select"
                    name="triggerInterfaceMajor"
                    disabled={isReadOnly || isLoadingInterfaceMajors || isLoadingInterface}
                    value={_.get(simpleTrigger, 'interfaceMajor') || 0}
                    onChange={handleTriggerInterfaceMajorChange}
                    isInvalid={_.get(validationErrors, 'interfaceMajor') != null}
                  >
                    {renderInterfaceMajorOptions()}
                  </Form.Control>
                  <Form.Control.Feedback type="invalid">
                    {_.get(validationErrors, 'interfaceMajor')}
                  </Form.Control.Feedback>
                </Form.Group>
              </Col>
            )}
          </Form.Row>
          {hasSelectedInterface && (
            <>
              <Form.Row className="mb-2">
                <Col sm={12}>
                  <Form.Group controlId="triggerPath">
                    <Form.Label>Path</Form.Label>
                    <Form.Control
                      type="text"
                      autoComplete="off"
                      required
                      readOnly={isReadOnly || isLoadingInterfaceMajors || isLoadingInterface}
                      value={_.get(simpleTrigger, 'matchPath') || ''}
                      isInvalid={_.get(validationErrors, 'matchPath') != null}
                      onChange={handleTriggerInterfacePathChange}
                    />
                    <Form.Control.Feedback type="invalid">
                      {_.get(validationErrors, 'matchPath')}
                    </Form.Control.Feedback>
                  </Form.Group>
                </Col>
              </Form.Row>
              <Form.Row className="mb-2">
                <Col sm={4}>
                  <Form.Group controlId="triggerOperator">
                    <Form.Label>Operator</Form.Label>
                    <Form.Control
                      as="select"
                      name="triggerOperator"
                      disabled={isReadOnly || isLoadingInterfaceMajors || isLoadingInterface}
                      value={triggerValueMatchOperator || '*'}
                      onChange={handleTriggerInterfaceOperatorChange}
                      isInvalid={_.get(validationErrors, 'valueMatchOperator') != null}
                    >
                      {renderTriggerOperatorOptions()}
                    </Form.Control>
                    <Form.Control.Feedback type="invalid">
                      {_.get(validationErrors, 'valueMatchOperator')}
                    </Form.Control.Feedback>
                  </Form.Group>
                </Col>
                {hasSelectedOperator && (
                  <Col sm={8}>
                    <Form.Group controlId="triggerKnownValue">
                      <Form.Label>Value</Form.Label>
                      <Form.Control
                        type="text"
                        autoComplete="off"
                        required
                        readOnly={isReadOnly || isLoadingInterfaceMajors || isLoadingInterface}
                        value={String(_.get(simpleTrigger, 'knownValue') ?? '')}
                        onChange={handleTriggerInterfaceKnownValueChange}
                        isInvalid={_.get(validationErrors, 'knownValue') != null}
                      />
                      <Form.Control.Feedback type="invalid">
                        {_.get(validationErrors, 'knownValue')}
                      </Form.Control.Feedback>
                    </Form.Group>
                  </Col>
                )}
              </Form.Row>
            </>
          )}
        </>
      )}
    </Form>
  );
};

export default SimpleTriggerForm;
