/*
   This file is part of Astarte.

   Copyright 2020-2024 SECO Mind Srl

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
import FormModal from '../components/modals/Form';

interface AttributeKeyValue {
  key: string;
  value: string;
}

const attributeFormSchema: JSONSchema7 = {
  type: 'object',
  required: ['key', 'value'],
  properties: {
    key: {
      title: 'Key',
      type: 'string',
    },
    value: {
      title: 'Value',
      type: 'string',
    },
  },
};

interface NewAttributeModalProps {
  onCancel: () => void;
  onConfirm: ({ key, value }: AttributeKeyValue) => void;
  isAddingAttribute: boolean;
}

const NewAttributeModal = ({
  onCancel,
  onConfirm,
  isAddingAttribute,
}: NewAttributeModalProps): React.ReactElement => (
  <FormModal
    title="Add Attribute"
    schema={attributeFormSchema}
    confirmLabel="Add"
    onCancel={onCancel}
    onConfirm={onConfirm}
    isConfirming={isAddingAttribute}
  />
);

export default NewAttributeModal;
