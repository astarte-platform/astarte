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

import React, { ChangeEvent, useEffect, useState } from 'react';
import { Button, Form, Modal, Table } from 'react-bootstrap';
import {
  AstarteTriggerDeliveryPolicyDTO,
  AstarteTriggerDeliveryPolicyHandlerDTO,
} from 'astarte-client/types/dto';
import Icon from './Icon';

const checkInvalidCodes = (value: string) => {
  const containsInvalidCodes = value
    .split(',')
    .map((stringCode) => parseInt(stringCode, 10))
    .some((code) => Number.isNaN(code) || code < 400 || code > 599);
  return containsInvalidCodes;
};

type ErrorCodesControlProps = {
  name: string;
  value: string;
  readonly: boolean;
  onChange: (newValue: string) => void;
};

const ErrorCodesControl = ({ name, value, readonly, onChange }: ErrorCodesControlProps) => {
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange(e.target.value);
  };

  return (
    <>
      <Form.Control
        type="text"
        required
        name={name}
        readOnly={readonly}
        value={value}
        onChange={handleInputChange}
        isValid={!checkInvalidCodes(value)}
        isInvalid={checkInvalidCodes(value)}
      />
      <Form.Control.Feedback type="invalid">
        enter between 400 and 599 comma separated numbers
      </Form.Control.Feedback>
    </>
  );
};

const defaultHandler: AstarteTriggerDeliveryPolicyHandlerDTO = {
  on: 'any_error',
  strategy: 'discard',
};

type HandlerModalProps = {
  initialHandler?: AstarteTriggerDeliveryPolicyHandlerDTO;
  readOnly: boolean;
  showModal: boolean;
  closeModal: () => void;
  addHandler: (handler: AstarteTriggerDeliveryPolicyHandlerDTO) => void;
};

const HandlerModal = ({
  initialHandler,
  readOnly,
  showModal,
  closeModal,
  addHandler,
}: HandlerModalProps) => {
  const [handler] = useState<AstarteTriggerDeliveryPolicyHandlerDTO>(
    initialHandler || defaultHandler,
  );
  const [handlerOn, setHandlerOn] = useState(handler.on);
  const [handlerStrategy, setHandlerStrategy] = useState<string>(handler.strategy);
  const [selectedErrorType, setSelectedErrorType] = useState(
    typeof handlerOn === 'object' ? 'custom_errors' : 'any_error',
  );
  const [customErrorsText, setCustomErrorsText] = useState(
    typeof handlerOn === 'object' ? handler.on.toString() : '',
  );

  const handleOnChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const { value } = event.target;
    setSelectedErrorType(value);
    setHandlerOn(value as 'any_error' | 'client_error' | 'server_error' | number[]);
  };

  const handleStrategyChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const { value } = event.target;
    setHandlerStrategy(value);
  };

  const handleCodes = (value: string) => {
    setCustomErrorsText(value);
  };

  const handleAddErrorHandler = () => {
    let updatedHandler: AstarteTriggerDeliveryPolicyHandlerDTO;
    if (selectedErrorType === 'custom_errors') {
      const customErrorsArray = customErrorsText
        .split(',')
        .map((stringCode) => parseInt(stringCode, 10))
        .filter((code) => !Number.isNaN(code));
      updatedHandler = {
        on: customErrorsArray,
        strategy: handlerStrategy as 'discard' | 'retry',
      };
      addHandler(updatedHandler);
    } else {
      updatedHandler = {
        on: handlerOn,
        strategy: handlerStrategy as 'discard' | 'retry',
      };
      addHandler(updatedHandler);
    }
  };

  return (
    <>
      <Modal show={showModal} onHide={closeModal}>
        <Modal.Header closeButton>
          <Modal.Title>Error Handler</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <Form>
            <Form.Group className="mb-3" controlId="errorHandlerOn">
              <Form.Label>On</Form.Label>
              <Form.Select
                required
                name="on"
                disabled={readOnly}
                value={typeof handlerOn === 'object' ? 'custom_errors' : handlerOn.toString()}
                onChange={handleOnChange}
              >
                <option value="any_error">any_error</option>
                <option value="server_error">server_error</option>
                <option value="client_error">client_error</option>
                <option value="custom_errors">Enter custom array of error numbers (400-599)</option>
              </Form.Select>
            </Form.Group>
            {selectedErrorType === 'custom_errors' && (
              <ErrorCodesControl
                name="custom_errors"
                value={customErrorsText}
                readonly={!readOnly}
                onChange={handleCodes}
              />
            )}
            <Form.Group className="mb-3" controlId="errorHandlerStrategy">
              <Form.Label>Strategy</Form.Label>
              <Form.Select
                value={handlerStrategy}
                disabled={readOnly}
                required
                name="strategy"
                onChange={handleStrategyChange}
              >
                <option value="discard">Discard</option>
                <option value="retry">Retry</option>
              </Form.Select>
            </Form.Group>
          </Form>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={closeModal}>
            Close
          </Button>
          <Button
            disabled={selectedErrorType === 'custom_errors' && checkInvalidCodes(customErrorsText)}
            variant="primary"
            onClick={handleAddErrorHandler}
          >
            {initialHandler ? 'Edit' : 'Add'} Handler
          </Button>
        </Modal.Footer>
      </Modal>
    </>
  );
};

type AddHandlerModalProps = {
  isReadOnly: boolean;
  showModal: boolean;
  onCancel: () => void;
  onConfirm: (handler: AstarteTriggerDeliveryPolicyHandlerDTO) => void;
};

const AddHandlerModal = ({ isReadOnly, showModal, onCancel, onConfirm }: AddHandlerModalProps) => (
  <HandlerModal
    readOnly={isReadOnly}
    showModal={showModal}
    closeModal={onCancel}
    addHandler={onConfirm}
  />
);

type EditHandlerModalProps = {
  initialHandler: AstarteTriggerDeliveryPolicyHandlerDTO;
  isReadOnly: boolean;
  showModal: boolean;
  onCancel: () => void;
  onConfirm: (handler: AstarteTriggerDeliveryPolicyHandlerDTO) => void;
};

const EditHandlerModal = ({
  initialHandler,
  isReadOnly,
  showModal,
  onCancel,
  onConfirm,
}: EditHandlerModalProps) => (
  <HandlerModal
    initialHandler={initialHandler}
    readOnly={isReadOnly}
    showModal={showModal}
    closeModal={onCancel}
    addHandler={onConfirm}
  />
);

interface Props {
  isReadOnly: boolean;
  initialData: AstarteTriggerDeliveryPolicyDTO;
  onChange?: (updatedPolicy: AstarteTriggerDeliveryPolicyDTO) => unknown;
}

export default ({ isReadOnly, initialData, onChange }: Props): React.ReactElement => {
  const [isAddingHandler, setIsAddingHandler] = useState(false);
  const [handlerToEditIndex, setHandlerToEditIndex] = useState<null | number>(null);
  const [policyDraft, setPolicyDraft] = useState<AstarteTriggerDeliveryPolicyDTO>(initialData);

  const handleDeleteErrorHandler = (
    i: number,
    handlers: AstarteTriggerDeliveryPolicyHandlerDTO[],
  ) => {
    const newErrorHandlers = handlers.filter((_, index) => index !== i);
    setPolicyDraft({ ...initialData, error_handlers: newErrorHandlers });
  };

  useEffect(() => {
    if (onChange) {
      onChange(policyDraft);
    }
  }, [onChange, policyDraft]);

  return (
    <>
      <Form.Group controlId="policyHandler">
        {!isReadOnly && (
          <Button variant="link" className="p-0" onClick={() => setIsAddingHandler(true)}>
            <Icon icon="add" className="me-2" />
            Add Error Handler
          </Button>
        )}
        {!initialData.error_handlers.length && (
          <p className="text-danger" style={{ fontSize: '0.7em' }}>
            error handler is required
          </p>
        )}
        {initialData.error_handlers.length > 0 && (
          <Table responsive>
            <thead>
              <tr>
                <th>On</th>
                <th>Strategy</th>
                {!isReadOnly && <th className="action-column">Actions</th>}
              </tr>
            </thead>
            <tbody>
              {initialData.error_handlers.map((el, index) => (
                <tr key={index}>
                  <td>{el.on && el.on.toString()}</td>
                  <td>{el.strategy}</td>
                  {!isReadOnly && (
                    <td className="text-center">
                      <Icon
                        icon="edit"
                        onClick={() => setHandlerToEditIndex(index)}
                        className="color-grey me-2"
                      />
                      <Icon
                        icon="erase"
                        onClick={() => handleDeleteErrorHandler(index, initialData.error_handlers)}
                      />
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Form.Group>
      {isAddingHandler && (
        <AddHandlerModal
          onCancel={() => setIsAddingHandler(false)}
          onConfirm={(handler) => {
            if (initialData.error_handlers.findIndex((x) => x.on === handler.on) === -1) {
              setPolicyDraft({
                ...initialData,
                error_handlers: initialData.error_handlers.concat(handler),
              });
            }
            if (onChange) {
              onChange(policyDraft);
            }
            setIsAddingHandler(false);
          }}
          isReadOnly
          showModal={isAddingHandler}
        />
      )}

      {handlerToEditIndex != null && (
        <EditHandlerModal
          initialHandler={initialData.error_handlers[handlerToEditIndex]}
          onCancel={() => setHandlerToEditIndex(null)}
          onConfirm={(handler) => {
            initialData.error_handlers.splice(handlerToEditIndex, 1, handler);
            setPolicyDraft(initialData);
            if (onChange) {
              onChange(policyDraft);
            }
            setHandlerToEditIndex(null);
          }}
          isReadOnly
          showModal={handlerToEditIndex != null}
        />
      )}
    </>
  );
};
