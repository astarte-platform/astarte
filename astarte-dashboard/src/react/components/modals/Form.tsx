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

import React, { useState } from 'react';
import { Button, Form, Modal, Spinner } from 'react-bootstrap';
import type { ModalProps } from 'react-bootstrap';
import metaSchemaDraft04 from 'ajv/lib/refs/json-schema-draft-04.json';
import JsonSchemaForm from '@rjsf/bootstrap-4';
import type { WidgetProps } from '@rjsf/core';
import type { ComponentProps } from 'react';

const additionalMetaSchemas = [metaSchemaDraft04];

export interface TextWidgetProps extends WidgetProps {
  type?: string;
}

const TextWidget = ({
  id,
  required,
  readonly,
  disabled,
  placeholder,
  type,
  label,
  value,
  onChange,
  onBlur,
  onFocus,
  autofocus,
  options,
  schema,
  rawErrors = [],
}: TextWidgetProps) => {
  const handleChange = ({ target: { value: v } }: React.ChangeEvent<HTMLInputElement>) =>
    onChange(v === '' ? options.emptyValue : v);
  const handleBlur = ({ target: { value: v } }: React.FocusEvent<HTMLInputElement>) =>
    onBlur(id, v);
  const handleFocus = ({ target: { value: v } }: React.FocusEvent<HTMLInputElement>) =>
    onFocus(id, v);

  return (
    <Form.Group className="mb-0">
      <Form.Label className={rawErrors.length > 0 ? 'text-danger' : ''}>
        {label || schema.title}
      </Form.Label>
      <Form.Control
        id={id}
        autoFocus={autofocus}
        required={required}
        disabled={disabled}
        readOnly={readonly}
        placeholder={placeholder}
        className={rawErrors.length > 0 ? 'is-invalid' : ''}
        list={schema.examples ? `examples_${id}` : undefined}
        type={type || (schema.type as string)}
        value={value || value === 0 ? value : ''}
        onChange={handleChange}
        onBlur={handleBlur}
        onFocus={handleFocus}
      />
      {schema.examples ? (
        <datalist id={`examples_${id}`}>
          {(schema.examples as string[])
            .concat(schema.default ? ([schema.default] as string[]) : [])
            .map((example: any) => (
              // eslint-disable-next-line jsx-a11y/control-has-associated-label
              <option key={example} value={example} />
            ))}
        </datalist>
      ) : null}
    </Form.Group>
  );
};

// Delete custom widgets when this is issue is solved and 'placeholder' is supported
// https://github.com/rjsf-team/react-jsonschema-form/issues/1998
const widgets = {
  TextWidget,
};

type JsonSchemaFormProps = ComponentProps<typeof JsonSchemaForm>;

type BoostrapVariant =
  | 'primary'
  | 'secondary'
  | 'success'
  | 'warning'
  | 'danger'
  | 'info'
  | 'light'
  | 'dark'
  | 'link';

interface Props {
  cancelLabel?: string;
  confirmLabel?: string;
  confirmVariant?: BoostrapVariant;
  initialData?: JsonSchemaFormProps['formData'];
  isConfirming?: boolean;
  liveValidate?: boolean;
  onCancel: () => void;
  onConfirm: (formData: any) => void;
  schema: JsonSchemaFormProps['schema'];
  size?: ModalProps['size'];
  title: React.ReactNode;
  transformErrors?: JsonSchemaFormProps['transformErrors'];
  uiSchema?: JsonSchemaFormProps['uiSchema'];
}

const FormModal = ({
  cancelLabel = 'Cancel',
  confirmLabel = 'Confirm',
  confirmVariant = 'primary',
  initialData,
  isConfirming = false,
  liveValidate = false,
  onCancel,
  onConfirm,
  schema,
  size = 'lg',
  title,
  transformErrors,
  uiSchema,
}: Props): React.ReactElement => {
  const [formData, setFormData] = React.useState(initialData || null);
  const [hasSubmit, setHasSubmit] = useState(false);

  return (
    <Modal show centered size={size} onHide={onCancel}>
      <Modal.Header closeButton>
        <Modal.Title>{title}</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <div>
          <JsonSchemaForm
            schema={schema}
            additionalMetaSchemas={additionalMetaSchemas}
            uiSchema={uiSchema}
            widgets={widgets}
            formData={formData}
            liveValidate={liveValidate || hasSubmit}
            onChange={(event) => {
              setFormData(event.formData);
            }}
            onSubmit={(event) => onConfirm(event.formData)}
            showErrorList={false}
            transformErrors={transformErrors}
          >
            <hr style={{ display: 'block', marginLeft: '-1em', marginRight: '-1em' }} />
            <div className="d-flex justify-content-end">
              <Button variant="secondary mr-2" onClick={onCancel} style={{ minWidth: '5em' }}>
                {cancelLabel}
              </Button>
              <Button
                type="submit"
                variant={confirmVariant}
                disabled={isConfirming}
                onClick={() => setHasSubmit(true)}
                style={{ minWidth: '5em' }}
              >
                {isConfirming && (
                  <Spinner className="mr-2" size="sm" animation="border" role="status" />
                )}
                {confirmLabel}
              </Button>
            </div>
          </JsonSchemaForm>
        </div>
      </Modal.Body>
    </Modal>
  );
};

export default FormModal;
