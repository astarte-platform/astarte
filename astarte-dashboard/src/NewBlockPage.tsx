/*
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl

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
import { Button, Form, Spinner, Stack } from 'react-bootstrap';
import { AstarteCustomBlock } from 'astarte-client';
import _ from 'lodash';

import { actions, useStoreDispatch, useStoreSelector } from './store';
import { AlertsBanner, useAlerts } from './AlertManager';
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

export default (): React.ReactElement => {
  const [block, setBlock] = useState<BlockState>({
    name: '',
    source: '',
    type: 'producer',
    schema: '',
  });
  const [isValidated, setIsValidated] = useState(false);
  const [creationAlerts, creationAlertsController] = useAlerts();
  const navigate = useNavigate();
  const dispatch = useStoreDispatch();
  const isRegisteringBlock = useStoreSelector((selectors) =>
    selectors.isRegisteringBlock(block.name),
  );

  const createBlock = useCallback(() => {
    const newBlock = new AstarteCustomBlock({
      ...block,
      schema: JSON.parse(block.schema.trim()),
    });
    dispatch(actions.blocks.register(newBlock)).then((action) => {
      if (action.meta.requestStatus === 'fulfilled') {
        navigate('/blocks');
      } else {
        creationAlertsController.showError(
          `Couldn't create block: ${_.get(action, 'error.message')}`,
        );
      }
    });
  }, [dispatch, block, creationAlertsController, navigate]);

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
        <AlertsBanner alerts={creationAlerts} />
        <Form noValidate>
          <Stack gap={3}>
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
              <Form.Select
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
              </Form.Select>
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
          </Stack>
        </Form>
      </SingleCardPage>
      <div className="d-flex flex-column flex-md-row-reverse m-3">
        <Button
          variant="primary"
          onClick={isRegisteringBlock ? undefined : handleSubmit}
          disabled={isRegisteringBlock || !isValidBlock}
        >
          {isRegisteringBlock && (
            <Spinner as="span" size="sm" animation="border" role="status" className="me-2" />
          )}
          Create new block
        </Button>
      </div>
    </>
  );
};
