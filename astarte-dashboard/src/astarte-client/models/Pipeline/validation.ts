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

import _ from 'lodash';

import { AstartePipeline } from './index';
import type { AstarteValidationResult, AstarteValidationResults } from '../../types';

const validatePipelineName = (name: AstartePipeline['name']): AstarteValidationResult => {
  let error;
  let warning;
  const isValid = _.isString(name);
  if (!isValid) {
    error = 'Pipeline name must be a string';
  }
  return { isValid, error, warning };
};

const validatePipelineDescription = (
  description: AstartePipeline['description'],
): AstarteValidationResult => {
  let error;
  let warning;
  const isValid = _.isString(description);
  if (!isValid) {
    error = 'Pipeline description must be a string';
  }
  return { isValid, error, warning };
};

const validatePipelineSchema = (schema: AstartePipeline['schema']): AstarteValidationResult => {
  let error;
  let warning;
  const isValid = _.isPlainObject(schema);
  if (!isValid) {
    error = 'Pipeline schema must be a string';
  }
  return { isValid, error, warning };
};

const validatePipelineSource = (source: AstartePipeline['source']): AstarteValidationResult => {
  let error;
  let warning;
  const isValid = _.isString(source);
  if (!isValid) {
    error = 'Pipeline source must be a string';
  }
  return { isValid, error, warning };
};

const validatePipeline = (pipeline: AstartePipeline): AstarteValidationResults => {
  const validation: AstarteValidationResults = {
    isValid: true,
    errors: [],
    warnings: [],
    properties: {},
  };
  validation.properties.name = validatePipelineName(pipeline.name);
  validation.properties.description = validatePipelineDescription(pipeline.description);
  validation.properties.schema = validatePipelineSchema(pipeline.schema);
  validation.properties.source = validatePipelineSource(pipeline.source);

  Object.values(validation.properties).forEach((property) => {
    if (!property.isValid) {
      validation.isValid = false;
    }
    if (property.error) {
      validation.errors.push(property.error);
    }
    if (property.warning) {
      validation.warnings.push(property.warning);
    }
  });

  if (!validation.isValid && validation.errors.length === 0) {
    validation.errors.push('Pipeline is not valid');
  }

  return validation;
};

export default {
  validatePipeline,
  validatePipelineName,
  validatePipelineDescription,
  validatePipelineSchema,
  validatePipelineSource,
};
