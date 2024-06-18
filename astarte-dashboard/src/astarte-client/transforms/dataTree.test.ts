/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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

import { AstarteInterface } from 'astarte-client';

import { toAstarteDataTree } from './dataTree';

describe('DataTree for properties interface', () => {
  const iface = new AstarteInterface({
    name: 'test.astarte.PropertiesInterface',
    major: 1,
    minor: 0,
    type: 'properties',
    ownership: 'device',
    mappings: [
      {
        endpoint: '/%{room}/heating/active',
        type: 'boolean',
      },
      {
        endpoint: '/rooms/count',
        type: 'integer',
      },
    ],
  });

  it('creates an empty DataTree', () => {
    const data = {};
    const dataTree = toAstarteDataTree({ interface: iface, data });
    expect(dataTree).toEqual({
      dataKind: 'properties',
      endpoint: '',
      interface: iface,
      parent: null,
      children: [],
    });
  });
});

describe('DataTree for datastream individual interface', () => {
  const iface = new AstarteInterface({
    name: 'test.astarte.IndividualObjectInterface',
    major: 1,
    minor: 0,
    type: 'datastream',
    ownership: 'device',
    mappings: [
      {
        endpoint: '/humidity/value/current',
        type: 'double',
      },
      {
        endpoint: '/sensors/%{sensor}/estimated',
        type: 'double',
      },
    ],
  });

  it('creates an empty DataTree', () => {
    const data = {};
    const dataTree = toAstarteDataTree({ interface: iface, data });
    expect(dataTree).toEqual({
      dataKind: 'datastream_individual',
      endpoint: '',
      interface: iface,
      parent: null,
      children: [],
    });
  });
});

describe('DataTree for datastream object interface', () => {
  const iface = new AstarteInterface({
    name: 'test.astarte.AggregatedObjectInterface',
    major: 1,
    minor: 0,
    type: 'datastream',
    ownership: 'device',
    aggregation: 'object',
    mappings: [
      {
        endpoint: '/sensors/%{sensor_id}/value/boolean',
        type: 'boolean',
      },
      {
        endpoint: '/sensors/%{sensor_id}/value/double',
        type: 'double',
      },
    ],
  });

  it('creates an empty DataTree', () => {
    const data = {};
    const dataTree = toAstarteDataTree({ interface: iface, data });
    expect(dataTree).toEqual({
      dataKind: 'datastream_object',
      endpoint: '',
      interface: iface,
      parent: null,
      children: [],
    });
  });
});
