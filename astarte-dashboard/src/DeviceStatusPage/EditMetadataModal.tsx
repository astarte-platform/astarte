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

const metadataValueFormSchema: JSONSchema7 = {
  type: 'object',
  required: ['value'],
  properties: {
    value: {
      title: 'Metadata',
      type: 'string',
    },
  },
};

interface EditMetadataModalProps {
  onCancel: () => void;
  onConfirm: ({ value }: { value: string }) => void;
  targetMetadata: string;
  isUpdatingMetadata: boolean;
}

const EditMetadataModal = ({
  onCancel,
  onConfirm,
  targetMetadata,
  isUpdatingMetadata,
}: EditMetadataModalProps): React.ReactElement => (
  <FormModal
    title={`Edit "${targetMetadata}"`}
    schema={metadataValueFormSchema}
    onCancel={onCancel}
    onConfirm={onConfirm}
    isConfirming={isUpdatingMetadata}
  />
);

export default EditMetadataModal;
