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

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Col, Container, Form, Row } from 'react-bootstrap';
import { AstarteInterface, AstarteTrigger, AstarteSimpleTrigger } from 'astarte-client';
import _ from 'lodash';

import SimpleTriggerForm from './SimpleTriggerForm';
import TriggerActionForm from './TriggerActionForm';
import NewAmqpHeaderModal from './NewAmqpHeaderModal';
import NewHttpHeaderModal from './NewHttpHeaderModal';
import EditAmqpHeaderModal from './EditAmqpHeaderModal';
import EditHttpHeaderModal from './EditHttpHeaderModal';
import RemoveAmqpHeaderModal from './RemoveAmqpHeaderModal';
import RemoveHttpHeaderModal from './RemoveHttpHeaderModal';

const defaultTrigger: AstarteTrigger = {
  name: '',
  action: {
    httpUrl: '',
    httpMethod: 'post',
  },
  simpleTriggers: [
    {
      type: 'data_trigger',
      on: 'incoming_data',
      interfaceName: '*',
      matchPath: '/*',
      valueMatchOperator: '*',
    },
  ],
};

const formatJSON = (json: unknown): string => JSON.stringify(json, null, 4);

const formatJSONText = (text: string): string => {
  try {
    return formatJSON(JSON.parse(text));
  } catch {
    return text;
  }
};

const getNestedValidationErrors = (errors: { [key: string]: string }, prefix: string) =>
  _.mapKeys(
    _.pickBy(errors, (errorValue, errorName) => errorName.startsWith(prefix)),
    (errorValue, errorName) => errorName.slice(prefix.length + 1),
  );

type ActiveModal =
  | { modal: 'new-amqp-header' }
  | { modal: 'new-http-header' }
  | { modal: 'edit-amqp-header'; header: string }
  | { modal: 'edit-http-header'; header: string }
  | { modal: 'remove-amqp-header'; header: string }
  | { modal: 'remove-http-header'; header: string };

interface Props {
  fetchInterfacesName: () => Promise<string[]>;
  fetchInterfaceMajors: (interfaceName: string) => Promise<number[]>;
  fetchInterface: (params: {
    interfaceName: string;
    interfaceMajor: number;
  }) => Promise<AstarteInterface>;
  initialData?: AstarteTrigger;
  isReadOnly?: boolean;
  isSourceVisible?: boolean;
  onChange?: (updatedTrigger: AstarteTrigger, isValid: boolean) => unknown;
  onError?: (message: string, error: Error) => void;
  realm?: string | null;
}

export default ({
  fetchInterfacesName,
  fetchInterfaceMajors,
  fetchInterface,
  initialData,
  isReadOnly = false,
  isSourceVisible = false,
  onChange,
  onError,
  realm,
}: Props): React.ReactElement => {
  const [triggerDraft, setTriggerDraft] = useState<AstarteTrigger>(initialData || defaultTrigger);
  const [triggerSource, setTriggerSource] = useState(
    formatJSON(AstarteTrigger.toJSON(triggerDraft)),
  );
  const [triggerValidationErrors, setTriggerValidationErrors] = useState<{ [key: string]: string }>(
    {},
  );
  const [triggerSourceError, setTriggerSourceError] = useState('');
  const [interfacesName, setInterfacesName] = useState<string[]>([]);
  const [interfaceMajors, setInterfaceMajors] = useState<number[]>([]);
  const [triggerInterface, setTriggerInterface] = useState<AstarteInterface | null>(null);
  const [isLoadingInterfacesName, setIsLoadingInterfacesName] = useState(false);
  const [isLoadingInterfaceMajors, setIsLoadingInterfaceMajors] = useState(false);
  const [isLoadingInterface, setIsLoadingInterface] = useState(false);
  const [activeModal, setActiveModal] = useState<ActiveModal | null>(null);

  const actionValidationErrors = useMemo(
    () => getNestedValidationErrors(triggerValidationErrors, 'action'),
    [triggerValidationErrors],
  );
  const simpleTriggerValidationErrors = useMemo(
    () => getNestedValidationErrors(triggerValidationErrors, 'simpleTriggers[0]'),
    [triggerValidationErrors],
  );

  const handleFetchInterfacesName = useCallback(async () => {
    setIsLoadingInterfacesName(true);
    let names: string[] = [];
    try {
      names = await fetchInterfacesName();
    } catch (err) {
      if (onError) {
        onError(`Could not retrieve major versions for interface: ${err.message}`, err);
      }
    }
    setInterfacesName(names);
    setIsLoadingInterfacesName(false);
    return names;
  }, [fetchInterfacesName, onError]);

  const handleFetchInterfaceMajors = useCallback(
    async (interfaceName: string) => {
      setIsLoadingInterfaceMajors(true);
      let majors: number[] = [];
      try {
        majors = await fetchInterfaceMajors(interfaceName);
      } catch (err) {
        if (onError) {
          onError(
            `Could not retrieve major versions for ${interfaceName} interface: ${err.message}`,
            err,
          );
        }
      }
      setInterfaceMajors(majors);
      setIsLoadingInterfaceMajors(false);
      return majors;
    },
    [fetchInterfaceMajors, onError],
  );

  const handleFetchInterface = useCallback(
    async (params: { interfaceName: string; interfaceMajor: number }) => {
      setIsLoadingInterface(true);
      let iface: AstarteInterface | null = null;
      try {
        iface = await fetchInterface(params);
      } catch (err) {
        if (onError) {
          onError(
            `Could not retrieve selected interface ${params.interfaceName} v${params.interfaceMajor}: ${err.message}`,
            err,
          );
        }
      }
      setTriggerInterface(iface);
      setIsLoadingInterface(false);
      return iface;
    },
    [fetchInterface, onError],
  );

  const handleFetchInterfacesForTrigger = useCallback(
    async (trigger: AstarteTrigger) => {
      await handleFetchInterfacesName();
      const interfaceName = _.get(trigger, 'simpleTriggers[0].interfaceName');
      if (interfaceName === '*') {
        return trigger;
      }
      const ifaceMajors = await handleFetchInterfaceMajors(interfaceName);
      let ifaceMajor: number | undefined = _.get(trigger, 'simpleTriggers[0].interfaceMajor');
      if (ifaceMajor == null) {
        if (ifaceMajors.length === 0) {
          return trigger;
        }
        ifaceMajor = Math.max(...ifaceMajors);
        _.set(trigger as AstarteTrigger, 'simpleTriggers[0].interfaceMajor', ifaceMajor);
      }
      const interfaceMajor = ifaceMajor;
      await handleFetchInterface({ interfaceName, interfaceMajor });
      return trigger;
    },
    [handleFetchInterfacesName, handleFetchInterfaceMajors, handleFetchInterface],
  );

  const handleSimpleTriggerChange = useCallback((simpleTrigger: AstarteSimpleTrigger) => {
    setTriggerDraft((draft) => ({ ...draft, simpleTriggers: [simpleTrigger] }));
    if (simpleTrigger.type !== 'data_trigger' || simpleTrigger.interfaceName === '*') {
      setTriggerInterface(null);
    }
  }, []);

  const handleActionChange = useCallback(
    (action: AstarteTrigger['action']) =>
      setTriggerDraft((draft) => ({
        ...draft,
        action,
      })),
    [],
  );

  const handlePatchActionAmqpHeaders = useCallback(
    (newHeaders: { [header: string]: string | undefined }) => {
      setTriggerDraft((draft) => {
        const oldAmqpStaticHeaders = _.get(draft.action, 'amqpStaticHeaders') || {};
        const amqpStaticHeaders = _.omitBy(
          {
            ...oldAmqpStaticHeaders,
            ...newHeaders,
          },
          _.isUndefined,
        );
        return {
          ...draft,
          action: {
            ...draft.action,
            amqpStaticHeaders,
          },
        };
      });
    },
    [],
  );

  const handlePatchActionHttpHeaders = useCallback(
    (newHeaders: { [header: string]: string | undefined }) => {
      setTriggerDraft((draft) => {
        const oldHttpStaticHeaders = _.get(draft.action, 'httpStaticHeaders') || {};
        const httpStaticHeaders = _.omitBy(
          {
            ...oldHttpStaticHeaders,
            ...newHeaders,
          },
          _.isUndefined,
        );
        return {
          ...draft,
          action: {
            ...draft.action,
            httpStaticHeaders,
          },
        };
      });
    },
    [],
  );

  const handleTriggerNameChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setTriggerDraft((draft) => ({ ...draft, name: value }));
  }, []);

  const dismissModal = useCallback(() => setActiveModal(null), []);

  const handleAddActionAmqpHeader = useCallback(() => {
    setActiveModal({ modal: 'new-amqp-header' });
  }, []);

  const handleConfirmNewAmqpHeaderModal = useCallback(
    (formData: { key: string; value?: string }) => {
      handlePatchActionAmqpHeaders({ [formData.key]: formData.value || '' });
      dismissModal();
    },
    [],
  );

  const handleEditActionAmqpHeader = useCallback((header: string) => {
    setActiveModal({ modal: 'edit-amqp-header', header });
  }, []);

  const handleConfirmEditAmqpHeaderModal = useCallback(
    (formData: { value?: string }) => {
      if (activeModal != null && activeModal.modal === 'edit-amqp-header') {
        handlePatchActionAmqpHeaders({ [activeModal.header]: formData.value || '' });
      }
      dismissModal();
    },
    [activeModal],
  );

  const handleRemoveActionAmqpHeader = useCallback((header: string) => {
    setActiveModal({ modal: 'remove-amqp-header', header });
  }, []);

  const handleConfirmRemoveAmqpHeaderModal = useCallback(() => {
    if (activeModal != null && activeModal.modal === 'remove-amqp-header') {
      handlePatchActionAmqpHeaders({ [activeModal.header]: undefined });
    }
    dismissModal();
  }, [activeModal]);

  const handleAddActionHttpHeader = useCallback(() => {
    setActiveModal({ modal: 'new-http-header' });
  }, []);

  const handleConfirmNewHttpHeaderModal = useCallback(
    (formData: { key: string; value?: string }) => {
      handlePatchActionHttpHeaders({ [formData.key]: formData.value || '' });
      dismissModal();
    },
    [],
  );

  const handleEditActionHttpHeader = useCallback((header: string) => {
    setActiveModal({ modal: 'edit-http-header', header });
  }, []);

  const handleConfirmEditHttpHeaderModal = useCallback(
    (formData: { value?: string }) => {
      if (activeModal != null && activeModal.modal === 'edit-http-header') {
        handlePatchActionHttpHeaders({ [activeModal.header]: formData.value || '' });
      }
      dismissModal();
    },
    [activeModal],
  );

  const handleRemoveActionHttpHeader = useCallback((header: string) => {
    setActiveModal({ modal: 'remove-http-header', header });
  }, []);

  const handleConfirmRemoveHttpHeaderModal = useCallback(() => {
    if (activeModal != null && activeModal.modal === 'remove-http-header') {
      handlePatchActionHttpHeaders({ [activeModal.header]: undefined });
    }
    dismissModal();
  }, [activeModal]);

  const handleTriggerSourceChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setTriggerSource(value);
    let triggerSourceJSON: Record<string, unknown> | null = null;
    try {
      triggerSourceJSON = JSON.parse(value);
    } catch {
      triggerSourceJSON = null;
    }
    if (!triggerSourceJSON) {
      setTriggerSourceError('Invalid JSON');
      return;
    }
    let trigger: AstarteTrigger | null = null;
    try {
      trigger = AstarteTrigger.fromJSON(triggerSourceJSON as any);
    } catch {
      trigger = null;
    }
    if (!trigger) {
      setTriggerSourceError('Invalid Trigger');
      return;
    }
    if (_.get(trigger, 'simpleTriggers[0].type') === 'data_trigger') {
      handleFetchInterfacesForTrigger(trigger).then(setTriggerDraft);
    } else {
      setTriggerDraft(trigger);
    }
  }, []);

  useEffect(() => {
    const formattedTriggerSource = formatJSON(AstarteTrigger.toJSON(triggerDraft));
    setTriggerSource((source) =>
      formatJSONText(source) !== formattedTriggerSource ? formattedTriggerSource : source,
    );
    let validationErrors: { [key: string]: string } = {};
    try {
      AstarteTrigger.validation.validateSync(triggerDraft, {
        abortEarly: false,
        context: { realm, interface: triggerInterface },
      });
    } catch (err) {
      validationErrors = _.mapValues(_.keyBy(_.uniqBy(err.inner, 'path'), 'path'), 'message');
    }
    setTriggerValidationErrors(validationErrors);
    setTriggerSourceError(Object.values(validationErrors).join('. '));
    if (onChange) {
      const isValidTrigger = _.isEmpty(validationErrors);
      onChange(triggerDraft, isValidTrigger);
    }
  }, [triggerDraft, realm, triggerInterface]);

  useEffect(() => {
    if (initialData) {
      handleFetchInterfacesForTrigger(initialData);
    } else {
      handleFetchInterfacesName();
    }
  }, []);

  return (
    <Row>
      <Col md={isSourceVisible ? 6 : 12}>
        <Container fluid className="bg-white rounded p-3">
          <Form>
            <Form.Row className="mb-2">
              <Col sm={12}>
                <Form.Group controlId="triggerName">
                  <Form.Label>Name</Form.Label>
                  <Form.Control
                    type="text"
                    autoComplete="off"
                    required
                    readOnly={isReadOnly}
                    value={_.get(triggerDraft, 'name')}
                    onChange={handleTriggerNameChange}
                    isInvalid={_.get(triggerValidationErrors, 'name') != null}
                  />
                  <Form.Control.Feedback type="invalid">
                    {_.get(triggerValidationErrors, 'name')}
                  </Form.Control.Feedback>
                </Form.Group>
              </Col>
            </Form.Row>
          </Form>
          <SimpleTriggerForm
            fetchInterface={handleFetchInterface}
            fetchInterfaceMajors={handleFetchInterfaceMajors}
            interfacesName={interfacesName}
            interfaceMajors={interfaceMajors}
            isLoadingInterface={isLoadingInterface}
            isLoadingInterfacesName={isLoadingInterfacesName}
            isLoadingInterfaceMajors={isLoadingInterfaceMajors}
            isReadOnly={isReadOnly}
            onChange={handleSimpleTriggerChange}
            simpleTrigger={triggerDraft.simpleTriggers[0]}
            simpleTriggerInterface={triggerInterface}
            validationErrors={simpleTriggerValidationErrors}
          />
          <TriggerActionForm
            action={triggerDraft.action}
            isReadOnly={isReadOnly}
            onAddAmqpHeader={handleAddActionAmqpHeader}
            onAddHttpHeader={handleAddActionHttpHeader}
            onEditAmqpHeader={handleEditActionAmqpHeader}
            onEditHttpHeader={handleEditActionHttpHeader}
            onRemoveAmqpHeader={handleRemoveActionAmqpHeader}
            onRemoveHttpHeader={handleRemoveActionHttpHeader}
            onChange={handleActionChange}
            realm={realm}
            validationErrors={actionValidationErrors}
          />
        </Container>
      </Col>
      {isSourceVisible && (
        <Col md={6}>
          <Form.Group controlId="triggerSource" className="h-100 d-flex flex-column">
            <Form.Control
              as="textarea"
              className="flex-grow-1 text-monospace"
              autoComplete="off"
              spellCheck={false}
              required
              readOnly={isReadOnly}
              value={triggerSource}
              onChange={handleTriggerSourceChange}
              isInvalid={!!triggerSourceError}
            />
            <Form.Control.Feedback type="invalid">{triggerSourceError}</Form.Control.Feedback>
          </Form.Group>
        </Col>
      )}
      {activeModal != null && activeModal.modal === 'new-amqp-header' && (
        <NewAmqpHeaderModal onCancel={dismissModal} onConfirm={handleConfirmNewAmqpHeaderModal} />
      )}
      {activeModal != null && activeModal.modal === 'edit-amqp-header' && (
        <EditAmqpHeaderModal
          targetHeader={activeModal.header}
          onCancel={dismissModal}
          onConfirm={handleConfirmEditAmqpHeaderModal}
        />
      )}
      {activeModal != null && activeModal.modal === 'remove-amqp-header' && (
        <RemoveAmqpHeaderModal
          targetHeader={activeModal.header}
          onCancel={dismissModal}
          onConfirm={handleConfirmRemoveAmqpHeaderModal}
        />
      )}
      {activeModal != null && activeModal.modal === 'new-http-header' && (
        <NewHttpHeaderModal onCancel={dismissModal} onConfirm={handleConfirmNewHttpHeaderModal} />
      )}
      {activeModal != null && activeModal.modal === 'edit-http-header' && (
        <EditHttpHeaderModal
          targetHeader={activeModal.header}
          onCancel={dismissModal}
          onConfirm={handleConfirmEditHttpHeaderModal}
        />
      )}
      {activeModal != null && activeModal.modal === 'remove-http-header' && (
        <RemoveHttpHeaderModal
          targetHeader={activeModal.header}
          onCancel={dismissModal}
          onConfirm={handleConfirmRemoveHttpHeaderModal}
        />
      )}
    </Row>
  );
};
