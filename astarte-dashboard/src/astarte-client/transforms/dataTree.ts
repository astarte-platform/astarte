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

import _ from 'lodash';

import { AstarteInterface } from '../models';
import type {
  AstarteDataType,
  AstarteDataValue,
  AstarteDataTuple,
  AstartePropertyData,
  AstarteDatastreamData,
  AstarteDatastreamIndividualData,
  AstarteDatastreamObjectData,
  AstarteInterfaceValues,
  AstarteIndividualDatastreamInterfaceValue,
  AstarteAggregatedDatastreamInterfaceValue,
} from '../types';

const getEndpointDataType = (iface: AstarteInterface, endpoint: string): AstarteDataType => {
  const matchedMapping = AstarteInterface.findEndpointMapping(iface, endpoint);
  if (matchedMapping == null) {
    throw new Error(`Could not find an interface mapping for the endpoint ${endpoint}`);
  }
  return matchedMapping.type;
};

const isAstarteDataValue = (value: unknown): value is AstarteDataValue =>
  !_.isUndefined(value) && (!_.isPlainObject(value) || _.isNull(value));

const isPropertiesInterfaceValue = (value: unknown): value is AstarteDataValue =>
  isAstarteDataValue(value);

const isIndividualDatastreamInterfaceValue = (
  value: unknown,
): value is AstarteIndividualDatastreamInterfaceValue => isAstarteDataValue(_.get(value, 'value'));

const isIndividualDatastreamInterfaceValues = (
  value: unknown,
): value is AstarteIndividualDatastreamInterfaceValue[] =>
  _.isArray(value) && value.every(isIndividualDatastreamInterfaceValue);

const isAggregatedDatastreamInterfaceValue = (
  value: unknown,
): value is AstarteAggregatedDatastreamInterfaceValue => Array.isArray(value);

type AstarteDataTreeKind = 'properties' | 'datastream_object' | 'datastream_individual';

const getDataTreeKind = (iface: AstarteInterface): AstarteDataTreeKind => {
  if (iface.type === 'properties') {
    return 'properties';
  }
  if (iface.aggregation === 'object') {
    return 'datastream_object';
  }
  return 'datastream_individual';
};

type JSON<Value> = Value | { [prop: string]: JSON<Value> };

type Equals<T, S> = [T] extends [S] ? ([S] extends [T] ? true : false) : false;

interface AstarteDataTreeNode<
  Data extends AstartePropertyData | AstarteDatastreamIndividualData | AstarteDatastreamObjectData
> {
  dataKind: AstarteDataTreeKind;
  name: string;
  endpoint: string;
  getParentNode: () => AstarteDataTreeNode<Data> | null;
  getNode: (endpoint: string) => AstarteDataTreeNode<Data> | null;
  getLeaves: () => AstarteDataTreeNode<Data>[];
  toData: () => Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamObjectData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamIndividualData[]
    : AstartePropertyData[];
  toLinearizedData: () => Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamData[]
    : AstartePropertyData[];
  toLastValue: () => JSON<AstarteDataValue>;
}

interface AstarteDataTreeLeafNodeParams<
  Data extends AstartePropertyData | AstarteDatastreamIndividualData | AstarteDatastreamObjectData
> {
  interface: AstarteInterface;
  data: Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamObjectData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamIndividualData[]
    : AstartePropertyData;
  endpoint?: string;
  parentNode?: AstarteDataTreeBranchNode<Data> | null;
}

class AstarteDataTreeLeafNode<
  Data extends AstartePropertyData | AstarteDatastreamIndividualData | AstarteDatastreamObjectData
> implements AstarteDataTreeNode<Data> {
  readonly dataKind: AstarteDataTreeKind;

  readonly endpoint: string;

  private readonly parent: AstarteDataTreeBranchNode<Data> | null;

  private readonly data: Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamObjectData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamIndividualData[]
    : AstartePropertyData;

  private readonly linearizedData: Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamData[]
    : AstartePropertyData;

  constructor({
    interface: iface,
    data,
    endpoint = '',
    parentNode = null,
  }: AstarteDataTreeLeafNodeParams<Data>) {
    this.endpoint = endpoint;
    this.parent = parentNode;
    this.dataKind = getDataTreeKind(iface);
    this.data = data;
    if (iface.type === 'properties') {
      // @ts-expect-error cannot correctly infer from generics
      this.linearizedData = data as AstartePropertyData;
    } else if (iface.type === 'datastream' && iface.aggregation === 'individual') {
      const interfaceData = data as AstarteDatastreamIndividualData[];
      // @ts-expect-error cannot correctly infer from generics
      this.linearizedData = interfaceData.map((obj) => ({
        endpoint: obj.endpoint,
        timestamp: obj.timestamp,
        ...({ type: obj.type, value: obj.value } as AstarteDataTuple),
      })) as AstarteDatastreamData[];
    } else {
      const interfaceData = data as AstarteDatastreamObjectData[];
      // @ts-expect-error cannot correctly infer from generics
      this.linearizedData = interfaceData
        .map((obj) =>
          Object.entries(obj.value).map(([prop, propValue]) => ({
            endpoint: `${obj.endpoint}/${prop}`,
            timestamp: obj.timestamp,
            ...propValue,
          })),
        )
        .flat() as AstarteDatastreamData[];
    }
  }

  getParentNode(): AstarteDataTreeBranchNode<Data> | null {
    return this.parent;
  }

  getNode(endpoint: string): AstarteDataTreeLeafNode<Data> | null {
    const sanitizedEndpoint = endpoint.replace(/\/$/, '');
    if (sanitizedEndpoint === this.endpoint) {
      return this;
    }
    return null;
  }

  getLeaves(): AstarteDataTreeLeafNode<Data>[] {
    return [this];
  }

  toData(): Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamObjectData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamIndividualData[]
    : [AstartePropertyData] {
    // @ts-expect-error cannot correctly infer from generics
    return _.isArray(this.data) ? this.data : [this.data];
  }

  toLinearizedData(): Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamData[]
    : [AstartePropertyData] {
    // @ts-expect-error cannot correctly infer from generics
    return _.isArray(this.linearizedData) ? this.linearizedData : [this.linearizedData];
  }

  toLastValue(): JSON<AstarteDataValue> {
    if (this.dataKind === 'properties') {
      const data = this.data as AstartePropertyData;
      return data.value;
    }
    if (this.dataKind === 'datastream_individual') {
      const data = this.data as AstarteDatastreamIndividualData[];
      const lastData: AstarteDatastreamIndividualData | undefined = _.last(
        _.orderBy(data, ['timestamp'], ['asc']),
      );
      return lastData ? lastData.value : null;
    }
    const data = this.data as AstarteDatastreamObjectData[];
    const lastData: AstarteDatastreamObjectData | undefined = _.last(
      _.orderBy(data, ['timestamp'], ['asc']),
    );
    return lastData ? _.mapValues(lastData.value, (valueTuple) => valueTuple.value) : null;
  }

  get name(): string {
    return this.parent != null ? this.endpoint.replace(`${this.parent.endpoint}/`, '') : '';
  }
}

interface AstarteDataTreeBranchNodeParams<
  Data extends AstartePropertyData | AstarteDatastreamIndividualData | AstarteDatastreamObjectData
> {
  interface: AstarteInterface;
  data: AstarteInterfaceValues;
  endpoint?: string;
  parentNode?: AstarteDataTreeBranchNode<Data> | null;
}
class AstarteDataTreeBranchNode<
  Data extends AstartePropertyData | AstarteDatastreamIndividualData | AstarteDatastreamObjectData
> implements AstarteDataTreeNode<Data> {
  readonly dataKind: AstarteDataTreeKind;

  readonly endpoint: string;

  private readonly parent: AstarteDataTreeBranchNode<Data> | null;

  private readonly children: Array<AstarteDataTreeBranchNode<Data> | AstarteDataTreeLeafNode<Data>>;

  constructor({
    interface: iface,
    data,
    endpoint = '',
    parentNode = null,
  }: AstarteDataTreeBranchNodeParams<Data>) {
    this.endpoint = endpoint;
    this.parent = parentNode;
    this.dataKind = getDataTreeKind(iface);
    if (iface.type === 'properties') {
      // @ts-expect-error cannot correctly infer from generics
      this.children = Object.entries(data).map(([prop, propValue]) =>
        toPropertiesTreeNode({
          interface: iface,
          data: propValue,
          endpoint: `${endpoint}/${prop}`,
          // @ts-expect-error cannot correctly infer from generics
          parentNode: this as AstarteDataTreeBranchNode<AstartePropertyData>,
        }),
      ) as Array<AstarteDataTreeBranchNode<Data> | AstarteDataTreeLeafNode<Data>>;
    } else if (iface.type === 'datastream' && iface.aggregation === 'individual') {
      // @ts-expect-error cannot correctly infer from generics
      this.children = Object.entries(data).map(([prop, propValue]) =>
        toDatastreamIndividualTreeNode({
          interface: iface,
          data: propValue,
          endpoint: `${endpoint}/${prop}`,
          // @ts-expect-error cannot correctly infer from generics
          parentNode: this as AstarteDataTreeBranchNode<AstarteDatastreamIndividualData>,
        }),
      ) as Array<AstarteDataTreeBranchNode<Data> | AstarteDataTreeLeafNode<Data>>;
    } else {
      // @ts-expect-error cannot correctly infer from generics
      this.children = Object.entries(data).map(([prop, propValue]) =>
        toDatastreamObjectTreeNode({
          interface: iface,
          data: propValue,
          endpoint: `${endpoint}/${prop}`,
          // @ts-expect-error cannot correctly infer from generics
          parentNode: this as AstarteDataTreeBranchNode<AstarteDatastreamObjectData>,
        }),
      ) as Array<AstarteDataTreeBranchNode<Data> | AstarteDataTreeLeafNode<Data>>;
    }
  }

  getParentNode(): AstarteDataTreeBranchNode<Data> | null {
    return this.parent;
  }

  getNode(
    endpoint: string,
  ): AstarteDataTreeBranchNode<Data> | AstarteDataTreeLeafNode<Data> | null {
    const sanitizedEndpoint = endpoint.replace(/\/$/, '');
    if (sanitizedEndpoint === this.endpoint) {
      return this;
    }
    if (this.children.length === 0) {
      return null;
    }
    let foundNode: AstarteDataTreeBranchNode<Data> | AstarteDataTreeLeafNode<Data> | null = null;
    this.children.forEach((child) => {
      const node = child.getNode(sanitizedEndpoint);
      if (node != null) {
        foundNode = node;
      }
    });
    return foundNode;
  }

  getLeaves(): AstarteDataTreeLeafNode<Data>[] {
    return this.children.map((child) => child.getLeaves()).flat();
  }

  toData(): Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamObjectData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamIndividualData[]
    : AstartePropertyData[] {
    // @ts-expect-error cannot correctly infer from generics
    return this.getLeaves()
      .map((leaf) => leaf.toData())
      .flat();
  }

  toLinearizedData(): Equals<Data, AstarteDatastreamObjectData> extends true
    ? AstarteDatastreamData[]
    : Equals<Data, AstarteDatastreamIndividualData> extends true
    ? AstarteDatastreamData[]
    : AstartePropertyData[] {
    // @ts-expect-error cannot correctly infer from generics
    return this.getLeaves()
      .map((leaf) => leaf.toLinearizedData())
      .flat();
  }

  toLastValue(): JSON<AstarteDataValue> {
    return this.children.reduce(
      (acc, child) => ({
        ...acc,
        [child.name]: child.toLastValue(),
      }),
      {},
    );
  }

  get name(): string {
    return this.parent != null ? this.endpoint.replace(`${this.parent.endpoint}/`, '') : '';
  }
}

function toAstarteDataTree(params: {
  interface: AstarteInterface;
  data: AstarteInterfaceValues;
  endpoint?: string;
}):
  | AstarteDataTreeNode<AstartePropertyData>
  | AstarteDataTreeNode<AstarteDatastreamIndividualData>
  | AstarteDataTreeNode<AstarteDatastreamObjectData> {
  if (params.interface.type === 'properties') {
    return toPropertiesTreeNode({
      interface: params.interface,
      data: params.data,
      endpoint: params.endpoint || '',
      parentNode: null,
    });
  }
  if (params.interface.type === 'datastream' && params.interface.aggregation === 'individual') {
    return toDatastreamIndividualTreeNode({
      interface: params.interface,
      data: params.data,
      endpoint: params.endpoint || '',
      parentNode: null,
    });
  }
  return toDatastreamObjectTreeNode({
    interface: params.interface,
    data: params.data,
    endpoint: params.endpoint || '',
    parentNode: null,
  });
}

function toPropertiesTreeNode(params: {
  interface: AstarteInterface;
  data: AstarteInterfaceValues;
  endpoint: string;
  parentNode: AstarteDataTreeBranchNode<AstartePropertyData> | null;
}): AstarteDataTreeBranchNode<AstartePropertyData> | AstarteDataTreeLeafNode<AstartePropertyData> {
  if (isPropertiesInterfaceValue(params.data)) {
    return new AstarteDataTreeLeafNode<AstartePropertyData>({
      interface: params.interface,
      data: {
        endpoint: params.endpoint,
        ...({
          value: params.data,
          type: getEndpointDataType(params.interface, params.endpoint),
        } as AstarteDataTuple),
      },
      endpoint: params.endpoint,
      parentNode: params.parentNode,
    });
  }
  return new AstarteDataTreeBranchNode<AstartePropertyData>({
    interface: params.interface,
    data: params.data,
    endpoint: params.endpoint,
    parentNode: params.parentNode,
  });
}

function toDatastreamIndividualTreeNode(params: {
  interface: AstarteInterface;
  data: AstarteInterfaceValues;
  endpoint: string;
  parentNode: AstarteDataTreeBranchNode<AstarteDatastreamIndividualData> | null;
}):
  | AstarteDataTreeBranchNode<AstarteDatastreamIndividualData>
  | AstarteDataTreeLeafNode<AstarteDatastreamIndividualData> {
  if (isIndividualDatastreamInterfaceValues(params.data)) {
    const leafData: AstarteDatastreamIndividualData[] = params.data.map((dataValue) => ({
      endpoint: params.endpoint,
      timestamp: dataValue.timestamp,
      ...({
        value: dataValue.value,
        type: getEndpointDataType(params.interface, params.endpoint),
      } as AstarteDataTuple),
    }));
    return new AstarteDataTreeLeafNode<AstarteDatastreamIndividualData>({
      interface: params.interface,
      data: leafData,
      endpoint: params.endpoint,
      parentNode: params.parentNode,
    });
  }
  if (isIndividualDatastreamInterfaceValue(params.data)) {
    const leafData: AstarteDatastreamIndividualData[] = [
      {
        endpoint: params.endpoint,
        timestamp: params.data.timestamp,
        ...({
          value: params.data.value,
          type: getEndpointDataType(params.interface, params.endpoint),
        } as AstarteDataTuple),
      },
    ];
    return new AstarteDataTreeLeafNode<AstarteDatastreamIndividualData>({
      interface: params.interface,
      data: leafData,
      endpoint: params.endpoint,
      parentNode: params.parentNode,
    });
  }
  return new AstarteDataTreeBranchNode<AstarteDatastreamIndividualData>({
    interface: params.interface,
    data: params.data,
    endpoint: params.endpoint,
    parentNode: params.parentNode,
  });
}

function toDatastreamObjectTreeNode(params: {
  interface: AstarteInterface;
  data: AstarteInterfaceValues;
  endpoint: string;
  parentNode: AstarteDataTreeBranchNode<AstarteDatastreamObjectData> | null;
}):
  | AstarteDataTreeBranchNode<AstarteDatastreamObjectData>
  | AstarteDataTreeLeafNode<AstarteDatastreamObjectData> {
  if (isAggregatedDatastreamInterfaceValue(params.data)) {
    const leafData: AstarteDatastreamObjectData[] = params.data.map((obj) => ({
      endpoint: params.endpoint,
      timestamp: obj.timestamp,
      value: Object.entries(_.omit(obj, 'timestamp')).reduce(
        (acc, [objProp, objPropValue]) => ({
          ...acc,
          [objProp]: {
            value: objPropValue,
            type: getEndpointDataType(params.interface, `${params.endpoint}/${objProp}`),
          } as AstarteDataTuple,
        }),
        {},
      ),
    }));
    return new AstarteDataTreeLeafNode<AstarteDatastreamObjectData>({
      interface: params.interface,
      data: leafData,
      endpoint: params.endpoint,
      parentNode: params.parentNode,
    });
  }
  return new AstarteDataTreeBranchNode<AstarteDatastreamObjectData>({
    interface: params.interface,
    data: params.data,
    endpoint: params.endpoint,
    parentNode: params.parentNode,
  });
}

export { toAstarteDataTree };

export type { AstarteDataTreeNode, AstarteDataTreeKind };
