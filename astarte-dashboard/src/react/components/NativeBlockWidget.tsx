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
import { DefaultPortLabel, DiagramEngine } from '@projectstorm/react-diagrams';

import NativeBlockModel from '../models/NativeBlockModel';

interface Props {
  engine: DiagramEngine;
  node: NativeBlockModel;
  hasSettings: boolean;
}

const NativeBlockWidget = ({ engine, node, hasSettings }: Props): React.ReactElement => {
  const { name } = node;
  const inPorts = node.getInPorts();
  const outPorts = node.getOutPorts();

  const classes = ['native-node', node.blockType];
  if (node.isSelected()) {
    classes.push('selected');
  }

  return (
    <div className={classes.join(' ')} data-default-node-name={name}>
      <div className="node-header">
        <div className="node-title">{name}</div>
        {hasSettings && (
          <div className="settings-icon" onClick={(e) => node.onSettingsClick(e, node)}>
            <i className="fas fa-cog" />
          </div>
        )}
      </div>
      <div className="ports">
        <div className="port-container">
          {inPorts.map((port) => (
            <DefaultPortLabel engine={engine} port={port} key={port.getOptions().id} />
          ))}
        </div>
        <div className="port-container">
          {outPorts.map((port) => (
            <DefaultPortLabel engine={engine} port={port} key={port.getOptions().id} />
          ))}
        </div>
      </div>
    </div>
  );
};

export default NativeBlockWidget;
