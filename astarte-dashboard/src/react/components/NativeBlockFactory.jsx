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

import React from 'react';
import _ from 'lodash';
import { AbstractReactFactory } from '@projectstorm/react-canvas-core';
import NativeBlockModel from '../models/NativeBlockModel';
import NativeBlockWidget from './NativeBlockWidget';

class NativeBlockFactory extends AbstractReactFactory {
  constructor(blockDefinitions) {
    super('astarte-native');

    this.updateDefinitions(blockDefinitions);
  }

  generateReactWidget(event) {
    const node = event.model;
    const { schema } = this.blockDefinitions.get(node.options.name);
    const hasSettings = !_.isEmpty(schema) && !_.isEmpty(schema.properties);

    return <NativeBlockWidget engine={this.engine} node={node} hasSettings={hasSettings} />;
  }

  generateModel({ name, onSettingsClick }) {
    const blockType = this.blockDefinitions.get(name).type;
    return new NativeBlockModel({
      name,
      blockType,
      onSettingsClick,
    });
  }

  updateDefinitions(blocks) {
    if (blocks && blocks.length > 0) {
      this.blockDefinitions = new Map(blocks.map((b) => [b.name, b]));
    } else {
      this.blockDefinitions = new Map();
    }
  }
}

export default NativeBlockFactory;
