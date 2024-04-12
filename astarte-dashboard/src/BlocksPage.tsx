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

import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Badge, Button, Card, Col, Container, Row, Spinner } from 'react-bootstrap';
import { AstarteNativeBlock } from 'astarte-client';
import type { AstarteBlock } from 'astarte-client';

import { actions, useStoreDispatch, useStoreSelector } from './store';
import WaitForData from './components/WaitForData';
import Empty from './components/Empty';

interface NewBlockCardProps {
  onCreate: () => void;
}

function NewBlockCard({ onCreate }: NewBlockCardProps) {
  return (
    <Card className="mb-4 h-100">
      <Card.Header as="h5">New Block</Card.Header>
      <Card.Body className="d-flex flex-column">
        <Card.Text>Create your custom block</Card.Text>
        <div className="mt-auto d-flex flex-column flex-md-row">
          <Button variant="secondary" onClick={onCreate}>
            Create
          </Button>
        </div>
      </Card.Body>
    </Card>
  );
}

const blockTypeToLabel = {
  consumer: 'Consumer',
  producer: 'Producer',
  producer_consumer: 'Producer & Consumer',
};

interface BlockCardProps {
  block: AstarteBlock;
  onShow: () => void;
}

function BlockCard({ block, onShow }: BlockCardProps) {
  return (
    <Card className="mb-4 h-100" data-testid={block.name}>
      <Card.Header as="h5" className="d-flex justify-content-between align-items-center">
        <Button variant="link" className="p-0" onClick={onShow}>
          {block.name}
        </Button>
        {block instanceof AstarteNativeBlock && (
          <Badge bg="secondary" className="h6 text-light">
            native
          </Badge>
        )}
      </Card.Header>
      <Card.Body className="d-flex flex-column">
        <Card.Text>{blockTypeToLabel[block.type]}</Card.Text>
        <div className="mt-auto d-flex flex-column flex-md-row">
          <Button variant="primary" onClick={onShow}>
            Show
          </Button>
        </div>
      </Card.Body>
    </Card>
  );
}

export default (): React.ReactElement => {
  const navigate = useNavigate();
  const dispatch = useStoreDispatch();
  const blocksData = useStoreSelector((selectors) => selectors.blocks());
  const blocksStatus = useStoreSelector((selectors) => selectors.blocksStatus());

  useEffect(() => {
    dispatch(actions.blocks.getList());
  }, [dispatch]);

  return (
    <Container fluid className="p-3">
      <h2>Blocks</h2>
      <Row xs={1} lg={2} xxl={3} className="mt-4 g-4">
        <Col>
          <NewBlockCard onCreate={() => navigate('/blocks/new')} />
        </Col>
        <WaitForData
          data={blocksData}
          status={blocksStatus}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty
              title="Couldn't load available blocks"
              onRetry={() => dispatch(actions.blocks.getList())}
            />
          }
        >
          {(blocks) => (
            <>
              {blocks.map((block) => (
                <Col key={block.name}>
                  <BlockCard block={block} onShow={() => navigate(`/blocks/${block.name}/edit`)} />
                </Col>
              ))}
            </>
          )}
        </WaitForData>
      </Row>
    </Container>
  );
};
