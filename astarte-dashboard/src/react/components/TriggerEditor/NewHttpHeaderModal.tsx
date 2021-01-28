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

import React from 'react';
import type { JSONSchema7 } from 'json-schema';

import FormModal from '../modals/Form';

const newHttpHeaderFormSchema: JSONSchema7 = {
  type: 'object',
  required: ['key'],
  properties: {
    key: {
      title: 'Header',
      type: 'string',
    },
    value: {
      title: 'Value',
      type: 'string',
    },
  },
};

interface NewHttpHeaderModalProps {
  onCancel: () => void;
  onConfirm: (formData: { key: string; value?: string }) => void;
}

const NewHttpHeaderModal = ({
  onCancel,
  onConfirm,
}: NewHttpHeaderModalProps): React.ReactElement => (
  <FormModal
    title="Add Custom HTTP Header"
    schema={newHttpHeaderFormSchema}
    onCancel={onCancel}
    onConfirm={onConfirm}
  />
);

export default NewHttpHeaderModal;
