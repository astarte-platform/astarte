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
/* eslint camelcase: 0 */

export interface AstarteMappingDTO {
  endpoint: string;
  type:
    | 'double'
    | 'integer'
    | 'boolean'
    | 'longinteger'
    | 'string'
    | 'binaryblob'
    | 'datetime'
    | 'doublearray'
    | 'integerarray'
    | 'booleanarray'
    | 'longintegerarray'
    | 'stringarray'
    | 'binaryblobarray'
    | 'datetimearray';
  reliability?: 'unreliable' | 'guaranteed' | 'unique';
  retention?: 'discard' | 'volatile' | 'stored';
  expiry?: number;
  database_retention_policy?: 'no_ttl' | 'use_ttl';
  database_retention_ttl?: number;
  allow_unset?: boolean;
  explicit_timestamp?: boolean;
  description?: string;
  doc?: string;
}
