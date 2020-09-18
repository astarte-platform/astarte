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

import React, { useCallback, useEffect, useState } from 'react';
import { CanvasWidget } from '@projectstorm/react-canvas-core';
import createEngine, { DiagramModel } from '@projectstorm/react-diagrams';
import NativeBlockFactory from './NativeBlockFactory';

const filterSortBlocks = (blocks, type) => {
  if (!blocks || blocks.length === 0) {
    return [];
  }

  return blocks
    .filter((block) => block.type === type)
    .sort((block1, block2) => block1.name > block2.name);
};

const BlockMenuItem = ({ block }) => (
  <div
    className={`block-item ${block.type}`}
    onDragStart={(e) => e.dataTransfer.setData('block-name', block.name)}
    draggable
  >
    {block.name}
  </div>
);

const EditorSidebar = ({ blocks }) => (
  <div className="flow-editor-sidebar">
    <div className="block-label">Producer</div>
    {filterSortBlocks(blocks, 'producer').map((block) => (
      <BlockMenuItem key={block.name} block={block} />
    ))}
    <div className="block-label">Producer & consumer</div>
    {filterSortBlocks(blocks, 'producer_consumer').map((block) => (
      <BlockMenuItem key={block.name} block={block} />
    ))}
    <div className="block-label">Consumer</div>
    {filterSortBlocks(blocks, 'consumer').map((block) => (
      <BlockMenuItem key={block.name} block={block} />
    ))}
  </div>
);

function getEngine(model, nodeFactory) {
  const engine = createEngine();
  engine.getNodeFactories().registerFactory(nodeFactory);
  engine.setModel(model);

  return engine;
}

const VisualFlowEditor = ({ className = '', blocks, model, onNodeSettingsClick }) => {
  const [nodeFactory] = useState(new NativeBlockFactory(blocks));
  const [engine] = useState(getEngine(model, nodeFactory));

  useEffect(() => {
    nodeFactory.updateDefinitions(blocks);
  }, [blocks]);

  const addBlock = useCallback(
    (name, position) => {
      const newNode = nodeFactory.generateModel({
        name,
        onSettingsClick: onNodeSettingsClick,
      });
      newNode.setPosition(position.x - 30, position.y - 20);
      model.addNode(newNode);
      engine.repaintCanvas();
    },
    [onNodeSettingsClick],
  );

  return (
    <div className={['flow-editor', className].join(' ')}>
      <EditorSidebar blocks={blocks} />
      <div
        className="canvas-container"
        onDragOver={(e) => e.preventDefault()}
        onDrop={(e) => {
          const blockName = e.dataTransfer.getData('block-name');
          addBlock(blockName, engine.getRelativeMousePoint(e));
        }}
      >
        <CanvasWidget engine={engine} />
      </div>
    </div>
  );
};

function getNewModel() {
  return new DiagramModel();
}

function nodeModelToSource(model) {
  const seenIds = new Set();
  const chain = [];
  const pipelineBlocks = model.getNodes();

  const sources = pipelineBlocks.filter((b) => b.blockType === 'producer');
  if (sources.length === 0) {
    throw new Error('Pipelines must start with a producer block');
  }

  if (sources.length > 1) {
    throw new Error('Multiple producer blocks are not supported');
  }

  const sourceBlock = sources[0];
  chain.push(sourceBlock);
  seenIds.add(sourceBlock.options.id);

  let prevBlock = sourceBlock;
  let nextBlock;
  let loopCounter = 0;

  do {
    const nextLinks = Object.values(prevBlock.outPorts[0].links);

    if (nextLinks.length === 0) {
      throw new Error('Pipelines must end with a consumer block');
    }

    if (nextLinks.length > 1) {
      throw new Error('Multiple out connections are not supported');
    }

    nextBlock = nextLinks[0].targetPort.parent;

    if (seenIds.has(nextBlock.options.id)) {
      throw new Error('Pipelines cannot form a loop');
    }

    chain.push(nextBlock);
    seenIds.add(nextBlock.options.id);
    prevBlock = nextBlock;

    loopCounter += 1;
    if (loopCounter > 50) {
      throw new Error('Pipeline too long');
    }
  } while (nextBlock.blockType !== 'consumer');

  return chain.map((block) => block.toScript()).join('\n| ');
}

export { getNewModel, nodeModelToSource };
export default VisualFlowEditor;
