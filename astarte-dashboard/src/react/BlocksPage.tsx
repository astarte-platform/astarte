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
import { useNavigate } from 'react-router-dom';
import { Badge, Button, Card, CardDeck, Container, Spinner } from 'react-bootstrap';
import AstarteClient, { AstarteNativeBlock } from 'astarte-client';
import type { AstarteBlock } from 'astarte-client';

import WaitForData from './components/WaitForData';
import Empty from './components/Empty';
import useFetch from './hooks/useFetch';

interface NewBlockCardProps {
  onCreate: () => void;
}

function NewBlockCard({ onCreate }: NewBlockCardProps) {
  return (
    <Card className="mb-4">
      <Card.Header as="h5">New Block</Card.Header>
      <Card.Body>
        <Card.Text>Create your custom block</Card.Text>
        <Button variant="secondary" onClick={onCreate}>
          Create
        </Button>
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
    <Card className="mb-4">
      <Card.Header as="h5" className="d-flex justify-content-between align-items-center">
        <Button variant="link" className="p-0" onClick={onShow}>
          {block.name}
        </Button>
        {block instanceof AstarteNativeBlock && (
          <Badge variant="secondary" className="h6 text-light">
            native
          </Badge>
        )}
      </Card.Header>
      <Card.Body>
        <Card.Text>{blockTypeToLabel[block.type]}</Card.Text>
        <Button variant="primary" onClick={onShow}>
          Show
        </Button>
      </Card.Body>
    </Card>
  );
}

interface Props {
  astarte: AstarteClient;
}

export default ({ astarte }: Props): React.ReactElement => {
  const blocksFetcher = useFetch(astarte.getBlocks);
  const navigate = useNavigate();

  return (
    <Container fluid className="p-3">
      <h2>Blocks</h2>
      <CardDeck className="mt-4">
        <NewBlockCard onCreate={() => navigate('/blocks/new')} />
        <WaitForData
          data={blocksFetcher.value}
          status={blocksFetcher.status}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty title="Couldn't load available blocks" onRetry={blocksFetcher.refresh} />
          }
        >
          {(blocks) => (
            <>
              {blocks.map((block, index) => (
                <React.Fragment key={`fragment-${index}`}>
                  {index % 2 ? <div className="w-100 d-none d-md-block" /> : null}
                  <BlockCard block={block} onShow={() => navigate(`/blocks/${block.name}/edit`)} />
                  {index === blocks.length - 1 && blocks.length % 2 === 0 ? (
                    <div className="w-50 d-none d-md-block" />
                  ) : null}
                </React.Fragment>
              ))}
            </>
          )}
        </WaitForData>
      </CardDeck>
    </Container>
  );
};
