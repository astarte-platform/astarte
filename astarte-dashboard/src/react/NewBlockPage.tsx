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

import React, { useCallback, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Form, Row, Spinner } from 'react-bootstrap';
import AstarteClient, { AstarteCustomBlock } from 'astarte-client';

import { useAlerts } from './AlertManager';
import SingleCardPage from './ui/SingleCardPage';

const isJSON = (string: string) => {
  try {
    JSON.parse(string);
    return true;
  } catch {
    return false;
  }
};

interface BlockState {
  name: AstarteCustomBlock['name'];
  source: AstarteCustomBlock['source'];
  type: AstarteCustomBlock['type'];
  schema: string;
}

interface Props {
  astarte: AstarteClient;
}

export default ({ astarte }: Props): React.ReactElement => {
  const [block, setBlock] = useState<BlockState>({
    name: '',
    source: '',
    type: 'producer',
    schema: '',
  });
  const [isValidated, setIsValidated] = useState(false);
  const [isCreatingBlock, setIsCreatingBlock] = useState(false);
  const creationAlerts = useAlerts();
  const navigate = useNavigate();

  const createBlock = useCallback(() => {
    setIsCreatingBlock(true);
    const newBlock = {
      ...block,
      schema: JSON.parse(block.schema.trim()),
    };
    astarte
      .registerBlock(newBlock)
      .then(() => navigate('/blocks'))
      .catch((err) => {
        setIsCreatingBlock(false);
        creationAlerts.showError(`Couldn't create block: ${err.message}`);
      });
  }, [block, creationAlerts.showError, navigate]);

  const isValidBlockName = /^[a-zA-Z][a-zA-Z0-9-_]*$/.test(block.name);
  const isValidBlockSource = block.source !== '';
  const isValidBlockType = ['producer', 'consumer', 'producer_consumer'].includes(block.type);
  const isValidBlockSchema = isJSON(block.schema.trim());
  const isValidBlock =
    isValidBlockName && isValidBlockSource && isValidBlockType && isValidBlockSchema;

  const handleSubmit = useCallback(() => {
    setIsValidated(true);
    if (isValidBlock) {
      createBlock();
    }
  }, [setIsValidated, createBlock, isValidBlock]);

  return (
    <>
      <SingleCardPage title="New Block" backLink="/blocks">
        <creationAlerts.Alerts />
        <Form noValidate>
          <Form.Group controlId="block-name">
            <Form.Label>Name</Form.Label>
            <Form.Control
              type="text"
              value={block.name}
              onChange={(e) => setBlock({ ...block, name: e.target.value })}
              isValid={isValidated && isValidBlockName}
              isInvalid={isValidated && !isValidBlockName}
            />
          </Form.Group>
          <Form.Group controlId="block-type">
            <Form.Label>Type</Form.Label>
            <Form.Control
              as="select"
              custom
              value={block.type}
              onChange={(e) =>
                setBlock({ ...block, type: e.target.value as AstarteCustomBlock['type'] })
              }
              isValid={isValidated && isValidBlockType}
              isInvalid={isValidated && !isValidBlockType}
            >
              <option value="producer">Producer</option>
              <option value="consumer">Consumer</option>
              <option value="producer_consumer">Producer &amp; Consumer</option>
            </Form.Control>
          </Form.Group>
          <Form.Group controlId="block-source">
            <Form.Label>Source</Form.Label>
            <Form.Control
              as="textarea"
              rows={12}
              value={block.source}
              onChange={(e) => setBlock({ ...block, source: e.target.value })}
              isValid={isValidated && isValidBlockSource}
              isInvalid={isValidated && !isValidBlockSource}
            />
          </Form.Group>
          <Form.Group controlId="block-schema">
            <Form.Label>Schema</Form.Label>
            <Form.Control
              as="textarea"
              rows={12}
              value={block.schema}
              onChange={(e) => setBlock({ ...block, schema: e.target.value })}
              isValid={isValidated && isValidBlockSchema}
              isInvalid={isValidated && !isValidBlockSchema}
            />
          </Form.Group>
        </Form>
      </SingleCardPage>
      <Row className="justify-content-end m-3">
        <Button
          variant="primary"
          onClick={isCreatingBlock ? undefined : handleSubmit}
          disabled={isCreatingBlock || !isValidBlock}
        >
          {isCreatingBlock && (
            <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
          )}
          Create new block
        </Button>
      </Row>
    </>
  );
};
