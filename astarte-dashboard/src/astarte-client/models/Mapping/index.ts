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

import * as yup from 'yup';
import _ from 'lodash';

import { fromAstarteMappingDTO, toAstarteMappingDTO } from '../../transforms/mapping';
import type { AstarteMappingDTO, AstarteDataType } from '../../types';

type AstarteMappingJSON = AstarteMappingDTO;

interface AstarteMappingObject {
  endpoint: string;

  type: AstarteDataType;

  reliability?: 'unreliable' | 'guaranteed' | 'unique';

  retention?: 'discard' | 'volatile' | 'stored';

  expiry?: number;

  databaseRetentionPolicy?: 'no_ttl' | 'use_ttl';

  databaseRetentionTtl?: number;

  allowUnset?: boolean;

  explicitTimestamp?: boolean;

  description?: string;

  documentation?: string;
}

const mappingEndpointRegex = /^(\/(%{([a-zA-Z][a-zA-Z0-9_]*)}|[a-zA-Z][a-zA-Z0-9_]*)){1,64}$/;
const mappingEndpointParamRegex = /^%{([a-zA-Z][a-zA-Z0-9_]*)}$/;

const astarteDataTypes: AstarteDataType[] = [
  'string',
  'boolean',
  'double',
  'integer',
  'longinteger',
  'binaryblob',
  'datetime',
  'doublearray',
  'integerarray',
  'booleanarray',
  'longintegerarray',
  'stringarray',
  'binaryblobarray',
  'datetimearray',
];

const astarteMappingObjectSchema: yup.ObjectSchema<AstarteMappingObject> = yup
  .object({
    endpoint: yup
      .string()
      .required()
      .matches(
        mappingEndpointRegex,
        'Interface endpoint must be a UNIX-like path (e.g. /my/path), with optional parameters in the %{name} form',
      ),
    type: yup.string().required().oneOf(astarteDataTypes),
    reliability: yup.string().oneOf(['unreliable', 'guaranteed', 'unique']).notRequired(),
    retention: yup.string().oneOf(['discard', 'volatile', 'stored']).notRequired(),
    expiry: yup.number().integer().min(0).notRequired(),
    databaseRetentionPolicy: yup.string().oneOf(['no_ttl', 'use_ttl']).notRequired(),
    databaseRetentionTtl: yup
      .number()
      .integer()
      .min(60)
      .lessThan(20 * 365 * 24 * 60 * 60)
      .notRequired(),
    allowUnset: yup.boolean().notRequired(),
    explicitTimestamp: yup.boolean().notRequired(),
    description: yup.string().max(1000).notRequired(),
    documentation: yup.string().max(100000).notRequired(),
  })
  .required();

const isEndpointParam = (endpointPart?: string) =>
  endpointPart == null ? false : mappingEndpointParamRegex.test(endpointPart);

const matchEndpointPart = ([part1, part2]: [string | undefined, string | undefined]) =>
  part1 === part2 || isEndpointParam(part1) || isEndpointParam(part2);

class AstarteMapping {
  endpoint: string;

  type: AstarteDataType;

  reliability?: 'unreliable' | 'guaranteed' | 'unique';

  retention?: 'discard' | 'volatile' | 'stored';

  expiry?: number;

  databaseRetentionPolicy?: 'no_ttl' | 'use_ttl';

  databaseRetentionTtl?: number;

  allowUnset?: boolean;

  explicitTimestamp?: boolean;

  description?: string;

  documentation?: string;

  constructor(obj: AstarteMappingObject) {
    const validatedObj = AstarteMapping.validation.validateSync(obj, { abortEarly: false });
    this.endpoint = validatedObj.endpoint;
    this.type = validatedObj.type;
    this.reliability = validatedObj.reliability;
    this.retention = validatedObj.retention;
    this.expiry = validatedObj.expiry;
    this.databaseRetentionPolicy = validatedObj.databaseRetentionPolicy;
    this.databaseRetentionTtl = validatedObj.databaseRetentionTtl;
    this.allowUnset = validatedObj.allowUnset;
    this.explicitTimestamp = validatedObj.explicitTimestamp;
    this.description = validatedObj.description;
    this.documentation = validatedObj.documentation;
  }

  static matchEndpoint(endpoint1: string, endpoint2: string): boolean {
    return _.zip(endpoint1.split('/'), endpoint2.split('/')).every(matchEndpointPart);
  }

  static validation = astarteMappingObjectSchema;

  static fromJSON(json: AstarteMappingJSON): AstarteMapping {
    return fromAstarteMappingDTO(json);
  }

  static toJSON(mapping: AstarteMapping): AstarteMappingJSON {
    return toAstarteMappingDTO(mapping);
  }
}

export type { AstarteMappingObject };

export { AstarteMapping, mappingEndpointRegex };
