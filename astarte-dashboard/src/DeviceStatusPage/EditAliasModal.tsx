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
import type { JSONSchema7 } from 'json-schema';
import FormModal from '../components/modals/Form';

const aliasValueFormSchema: JSONSchema7 = {
  type: 'object',
  required: ['value'],
  properties: {
    value: {
      title: 'Alias',
      type: 'string',
    },
  },
};

interface EditAliasModalProps {
  onCancel: () => void;
  onConfirm: ({ value }: { value: string }) => void;
  targetAlias: string;
  isUpdatingAlias: boolean;
}

const EditAliasModal = ({
  onCancel,
  onConfirm,
  targetAlias,
  isUpdatingAlias,
}: EditAliasModalProps): React.ReactElement => (
  <FormModal
    title={`Edit "${targetAlias}"`}
    schema={aliasValueFormSchema}
    onCancel={onCancel}
    onConfirm={onConfirm}
    isConfirming={isUpdatingAlias}
  />
);

export default EditAliasModal;
