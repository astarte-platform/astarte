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

export type AstarteDataValue = number | boolean | string | number[] | boolean[] | string[] | null;

export type AstarteDataType =
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

export type AstarteDataTuple =
  | { type: 'double'; value: number }
  | { type: 'integer'; value: number }
  | { type: 'boolean'; value: boolean }
  | { type: 'longinteger'; value: string }
  | { type: 'string'; value: string }
  | { type: 'binaryblob'; value: string }
  | { type: 'datetime'; value: string }
  | { type: 'doublearray'; value: number[] }
  | { type: 'integerarray'; value: number[] }
  | { type: 'booleanarray'; value: boolean[] }
  | { type: 'longintegerarray'; value: string[] }
  | { type: 'stringarray'; value: string[] }
  | { type: 'binaryblobarray'; value: string[] }
  | { type: 'datetimearray'; value: string[] }
  | { type: AstarteDataType; value: null };

export type AstartePropertyData = {
  endpoint: string;
} & AstarteDataTuple;

export type AstarteDatastreamData = {
  endpoint: string;
  timestamp: string;
} & AstarteDataTuple;

export type AstarteDatastreamIndividualData = {
  endpoint: string;
  timestamp: string;
} & AstarteDataTuple;

export type AstarteDatastreamObjectData = {
  endpoint: string;
  timestamp: string;
  value: {
    [path: string]: AstarteDataTuple;
  };
};
