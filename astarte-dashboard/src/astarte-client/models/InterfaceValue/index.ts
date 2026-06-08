/*
This file is part of Astarte.

Copyright 2024 SECO Mind Srl

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

import * as yup from 'yup';

const base64Regex = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;
const iso8601Regex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

const getValidationSchema = (type: string) => {
  switch (type) {
    case 'integer':
      return yup
        .number()
        .integer('The value must be an integer.')
        .max(2147483647, 'The value is too large.')
        .required('This field is required and must be an integer.')
        .typeError('The value must be an integer.');
    case 'longinteger':
      return yup
        .number()
        .test('is-safe-integer', 'The value is too large.', (value) => Number.isSafeInteger(value))
        .required('This field is required and must be a long integer.')
        .typeError('The value must be a long integer.');
    case 'double':
      return yup
        .number()
        .required('This field is required and must be a decimal number.')
        .typeError('The value must be a decimal number.');
    case 'boolean':
      return yup
        .boolean()
        .required('This field is required and must be true or false.')
        .typeError('The value must be either true or false.');
    case 'string':
      return yup
        .string()
        .required('This field is required and must be a string.')
        .typeError('The value must be a valid string.');
    case 'binaryblob':
      return yup
        .string()
        .matches(base64Regex, 'The value must be a valid binary blob encoded.')
        .required('This field is required and must be a binary blob.')
        .typeError('The value must be a valid binary blob.');
    case 'datetime':
      return yup
        .string()
        .matches(iso8601Regex, 'The date must be in the format "YYYY-MM-DDTHH:mm:ss.sssZ".')
        .required('This field is required and must be a valid datetime.')
        .typeError('The value must be a valid datetime.');
    case 'doublearray':
      return yup
        .array()
        .of(yup.number().typeError('Each item in the array must be a valid decimal number.'))
        .required('This field is required and must be an array of decimal numbers.')
        .typeError('Each item in the array must be a valid decimal number.');
    case 'integerarray':
      return yup
        .array()
        .of(
          yup
            .number()
            .integer('Each item in the array must be a valid integer.')
            .max(2147483647, 'The value is too large.')
            .typeError('Each item in the array must be a valid integer.'),
        )
        .required('This field is required and must be an array of integers.')
        .typeError('Each item in the array must be a valid integer.');
    case 'longintegerarray':
      return yup
        .array()
        .of(
          yup
            .number()
            .test('is-safe-integer', 'The value is too large.', (value) =>
              Number.isSafeInteger(value),
            )
            .typeError('Each item in the array must be a long integer.'),
        )
        .required('This field is required and must be an array of long integers.')
        .typeError('Each item in the array must be a long integer.');
    case 'booleanarray':
      return yup
        .array()
        .of(yup.boolean().typeError('Each item in the array must be either true or false.'))
        .required('This field is required and must be an array of booleans.')
        .typeError('Each item in the array must be either true or false.');
    case 'stringarray':
      return yup
        .array()
        .of(yup.string().typeError('Each item in the array must be a valid string.'))
        .required('This field is required and must be an array of strings.')
        .typeError('Each item in the array must be a valid string.');
    case 'binaryblobarray':
      return yup
        .array()
        .of(
          yup
            .string()
            .matches(base64Regex, 'Each item must be a valid binary blob encoded.')
            .typeError('Each item in the array must be a valid binary blob.'),
        )
        .required('This field is required and must be an array of binary blobs.')
        .typeError('Each item in the array must be a valid binary blob.');
    case 'datetimearray':
      return yup
        .array()
        .of(
          yup
            .string()
            .matches(iso8601Regex, 'Each item must be in the format "YYYY-MM-DDTHH:mm:ss.sssZ".')
            .typeError('Each item in the array must be a valid datetime string.'),
        )
        .required('This field is required and must be an array of datetime strings.')
        .typeError('Each item in the array must be a valid datetime string.');
    default:
      return yup.string().required('This field is required.');
  }
};

export { getValidationSchema };
