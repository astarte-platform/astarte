/* eslint-disable max-classes-per-file */
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

import { AstarteMapping } from '../Mapping';
import type { AstarteMappingObject } from '../Mapping';
import { fromAstarteInterfaceDTO, toAstarteInterfaceDTO } from '../../transforms/interface';
import type { AstarteInterfaceDTO } from '../../types';

type AstarteInterfaceJSON = AstarteInterfaceDTO;

interface AstarteInterfaceObject {
  name: string;

  major: number;

  minor: number;

  type: 'properties' | 'datastream';

  ownership: 'device' | 'server';

  aggregation?: 'individual' | 'object';

  description?: string;

  documentation?: string;

  mappings: AstarteMapping[];
}

const interfaceNameRegex = /^([a-zA-Z][a-zA-Z0-9]*\.([a-zA-Z0-9][a-zA-Z0-9-]*\.)*)?[a-zA-Z][a-zA-Z0-9]*$/;
const mappingEndpointPlaceholderRegex = /%{[a-zA-Z]+[a-zA-Z0-9_]*}/;

const getMappingEndpointPrefix = (endpoint: unknown) =>
  _.isString(endpoint) ? endpoint.split('/').slice(0, -1).join('/') : '';

const checkMappingsUniqueness = (mappings?: AstarteMappingObject[] | null): boolean => {
  if (mappings == null || mappings.length === 0) {
    return true;
  }
  const endpoints = mappings.map((mapping) => mapping.endpoint);
  const placeholdersRegex = new RegExp(mappingEndpointPlaceholderRegex, 'g');
  const normalizedEndpoints = endpoints.map((mapping) =>
    mapping.toLowerCase().replace(placeholdersRegex, ''),
  );
  return _.uniq(normalizedEndpoints).length === endpoints.length;
};

const checkMappingsHaveSamePrefix = (mappings?: AstarteMappingObject[] | null): boolean => {
  if (mappings == null || mappings.length === 0) {
    return true;
  }
  const endpoints = mappings.map((mapping) => mapping.endpoint);
  const endpointsPrefixes = endpoints.map(getMappingEndpointPrefix);
  return endpointsPrefixes.every((prefix) => prefix === endpointsPrefixes[0]);
};

const checkMappingsHaveSameAttributes = (mappings?: AstarteMappingObject[] | null): boolean => {
  if (mappings == null || mappings.length === 0) {
    return true;
  }
  return mappings.every(
    (mapping) =>
      mapping.retention === mappings[0].retention &&
      mapping.reliability === mappings[0].reliability &&
      mapping.expiry === mappings[0].expiry &&
      mapping.allowUnset === mappings[0].allowUnset &&
      mapping.explicitTimestamp === mappings[0].explicitTimestamp,
  );
};

const mappingsValidation = yup
  .array(AstarteMapping.validation)
  .max(1024)
  .defined()
  .test('unique-mappings', 'Mappings cannot have conflicting endpoints', checkMappingsUniqueness);

const astarteInterfaceObjectSchema: yup.ObjectSchema<AstarteInterfaceObject> = yup
  .object({
    name: yup
      .string()
      .required()
      .max(128)
      .matches(
        interfaceNameRegex,
        'Interface name has to be an unique, alphanumeric reverse internet domain name, not longer than 128 characters',
      ),
    major: yup.number().integer().min(0).required(),
    minor: yup
      .number()
      .integer()
      .min(0)
      .required()
      .when('major', {
        is: 0,
        then: yup.number().integer().min(1).required(),
      }),
    type: yup.string().oneOf(['properties', 'datastream']).required(),
    ownership: yup.string().oneOf(['device', 'server']).required(),
    aggregation: yup
      .string()
      .oneOf(['individual', 'object'])
      .when('type', {
        is: 'datastream',
        then: yup.string().oneOf(['individual', 'object']).notRequired(),
        otherwise: yup.string().strip(true),
      }),
    description: yup.string().max(1000).notRequired(),
    documentation: yup.string().max(100000).notRequired(),
    mappings: mappingsValidation.when(['type', 'aggregation'], {
      is: (type, aggregation) => type === 'datastream' && aggregation === 'object',
      then: mappingsValidation
        .test(
          'same-prefix-mappings',
          'Mapping endpoints in Object aggregate interfaces must have the same prefix',
          checkMappingsHaveSamePrefix,
        )
        .test(
          'same-attributes-mappings',
          'Mapping endpoints in Object aggregate interfaces must have the same attributes for retention, reliability, expiry, allowUnset, explicitTimestamp',
          checkMappingsHaveSameAttributes,
        ),
    }),
  })
  .required();

class AstarteInterface {
  name: string;

  major: number;

  minor: number;

  type: 'properties' | 'datastream';

  ownership: 'device' | 'server';

  aggregation?: 'individual' | 'object';

  description?: string;

  documentation?: string;

  mappings: AstarteMapping[];

  constructor(obj: AstarteInterfaceObject) {
    const validatedObj = AstarteInterface.validation.validateSync(obj, { abortEarly: false });
    this.name = validatedObj.name;
    this.major = validatedObj.major;
    this.minor = validatedObj.minor;
    this.type = validatedObj.type;
    this.ownership = validatedObj.ownership;
    if (validatedObj.type === 'datastream') {
      this.aggregation = validatedObj.aggregation || 'individual';
    }
    this.description = validatedObj.description;
    this.documentation = validatedObj.documentation;
    this.mappings = validatedObj.mappings.map((mapping) =>
      validatedObj.type === 'datastream'
        ? new AstarteMapping({
            ...mapping,
            explicitTimestamp: mapping.explicitTimestamp || false,
            reliability: mapping.reliability || 'unreliable',
            retention: mapping.retention || 'discard',
            expiry: mapping.expiry || 0,
            databaseRetentionPolicy: mapping.databaseRetentionPolicy || 'no_ttl',
          })
        : new AstarteMapping({
            ...mapping,
            allowUnset: mapping.allowUnset || false,
          }),
    );
  }

  static findEndpointMapping(iface: AstarteInterface, endpoint: string): AstarteMapping | null {
    return iface.mappings.find((m) => AstarteMapping.matchEndpoint(m.endpoint, endpoint)) || null;
  }

  static validation = astarteInterfaceObjectSchema;

  static fromJSON(json: AstarteInterfaceJSON): AstarteInterface {
    return fromAstarteInterfaceDTO(json);
  }

  static toJSON(iface: AstarteInterface): AstarteInterfaceJSON {
    return toAstarteInterfaceDTO(iface);
  }
}

export type { AstarteInterfaceObject };

export { AstarteInterface, interfaceNameRegex };
