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

import { fromAstarteMappingDTO, toAstarteMappingDTO } from './mapping';
import { AstarteInterface } from '../models/Interface';
import type { AstarteInterfaceDTO } from '../types';

export const fromAstarteInterfaceDTO = (dto: AstarteInterfaceDTO): AstarteInterface => {
  return new AstarteInterface({
    name: dto.interface_name,
    major: dto.version_major,
    minor: dto.version_minor,
    type: dto.type,
    ownership: dto.ownership,
    aggregation: dto.type === 'datastream' ? dto.aggregation : undefined,
    description: dto.description,
    documentation: dto.doc,
    mappings: (dto.mappings || []).map((mapping) => fromAstarteMappingDTO(mapping)),
  });
};

export const toAstarteInterfaceDTO = (obj: AstarteInterface): AstarteInterfaceDTO => {
  return obj.type === 'datastream'
    ? {
        interface_name: obj.name,
        version_major: obj.major,
        version_minor: obj.minor,
        type: obj.type,
        ownership: obj.ownership,
        aggregation: obj.aggregation || 'individual',
        description: obj.description,
        doc: obj.documentation,
        mappings: (obj.mappings || []).map((mapping) =>
          toAstarteMappingDTO({
            ...mapping,
            explicitTimestamp: mapping.explicitTimestamp || false,
            reliability: mapping.reliability || 'unreliable',
            retention: mapping.retention || 'discard',
            expiry: mapping.expiry || 0,
            databaseRetentionPolicy: mapping.databaseRetentionPolicy || 'no_ttl',
          }),
        ),
      }
    : {
        interface_name: obj.name,
        version_major: obj.major,
        version_minor: obj.minor,
        type: obj.type,
        ownership: obj.ownership,
        description: obj.description,
        doc: obj.documentation,
        mappings: (obj.mappings || []).map((mapping) =>
          toAstarteMappingDTO({
            ...mapping,
            allowUnset: mapping.allowUnset || false,
          }),
        ),
      };
};
