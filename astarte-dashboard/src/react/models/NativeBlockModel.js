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

import { DefaultPortModel, NodeModel, PortModelAlignment } from '@projectstorm/react-diagrams';
import _ from 'lodash';

function isEmptyValue(value) {
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  if (typeof value === 'object') {
    return _.isEmpty(value);
  }
  if (typeof value === 'string') {
    return value === '';
  }
  return !value;
}

function encodeValue(value) {
  if (Array.isArray(value)) {
    const encodedValues = value.map((v) => encodeValue(v));
    return `[${encodedValues.join(',')}]`;
  }
  if (typeof value === 'object') {
    const encodedValues = Object.entries(value).map(
      ([key, innerValue]) => `${key}: ${encodeValue(innerValue)}`,
    );
    return `{${encodedValues.join(',')}}`;
  }
  if (typeof value === 'string') {
    return `"${value}"`;
  }
  return value;
}

class NativeBlockModel extends NodeModel {
  constructor({ name, blockType, onSettingsClick = () => {} }) {
    super({
      type: 'astarte-native',
      name,
      blockType,
    });

    this.outPorts = [];
    if (blockType.includes('producer')) {
      const outPort = new DefaultPortModel({
        in: false,
        name: 'Out',
        label: 'Out',
        alignment: PortModelAlignment.RIGHT,
      });
      super.addPort(outPort);
      this.outPorts.push(outPort);
    }

    this.inPorts = [];
    if (blockType.includes('consumer')) {
      const inPort = new DefaultPortModel({
        in: true,
        name: 'In',
        label: 'In',
        alignment: PortModelAlignment.LEFT,
      });
      super.addPort(inPort);
      this.inPorts.push(inPort);
    }

    this.name = name;
    this.blockType = blockType;
    this.properties = {};
    this.onSettingsClick = onSettingsClick;
  }

  getInPorts() {
    return this.inPorts;
  }

  getOutPorts() {
    return this.outPorts;
  }

  getProperties() {
    return this.properties;
  }

  setProperties(properties) {
    this.properties = properties;
  }

  toScript() {
    const params = Object.entries(this.properties)
      .filter(([, value]) => !isEmptyValue(value))
      .map(([key, value]) => `\n    .${key}(${encodeValue(value)})`);
    return this.name + params.join('');
  }
}

export default NativeBlockModel;
