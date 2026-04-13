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

import validation from './validation';

export class AstartePipeline {
  name: string;

  description: string;

  schema: Record<string, unknown>;

  source: string;

  constructor(obj: AstartePipeline) {
    const pipelineValidation = validation.validatePipeline(obj);
    if (!pipelineValidation.isValid) {
      throw new Error(pipelineValidation.errors.join('\n'));
    }
    this.name = obj.name;
    this.description = obj.description;
    this.schema = obj.schema;
    this.source = obj.source;
  }

  static validatePipeline = validation.validatePipeline;

  static validatePipelineName = validation.validatePipelineName;

  static validatePipelineDescription = validation.validatePipelineDescription;

  static validatePipelineSchema = validation.validatePipelineSchema;

  static validatePipelineSource = validation.validatePipelineSource;
}
