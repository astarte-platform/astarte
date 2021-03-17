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
import { Link, useNavigate } from 'react-router-dom';
import { Button, Card, CardDeck, Container, Spinner } from 'react-bootstrap';
import type { AstartePipeline } from 'astarte-client';

import { useAstarte } from './AstarteManager';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';

interface NewPipelineCardProps {
  onCreate: () => void;
}

const NewPipelineCard = ({ onCreate }: NewPipelineCardProps): React.ReactElement => (
  <Card className="mb-4">
    <Card.Header as="h5">New Pipeline</Card.Header>
    <Card.Body>
      <Card.Text>Create your custom pipeline</Card.Text>
      <Button variant="secondary" onClick={onCreate}>
        Create
      </Button>
    </Card.Body>
  </Card>
);

interface PipelineCardProps {
  pipeline: AstartePipeline;
  onInstantiate: () => void;
  showLink: string;
}

const PipelineCard = ({
  pipeline,
  onInstantiate,
  showLink,
}: PipelineCardProps): React.ReactElement => (
  <Card className="mb-4">
    <Card.Header as="h5">
      <Link to={showLink}>{pipeline.name}</Link>
    </Card.Header>
    <Card.Body>
      <Card.Text>{pipeline.description}</Card.Text>
      <Button variant="primary" onClick={onInstantiate}>
        Instantiate
      </Button>
    </Card.Body>
  </Card>
);

export default (): React.ReactElement => {
  const astarte = useAstarte();
  const pipelinesFetcher = useFetch(astarte.client.getPipelines);
  const navigate = useNavigate();

  return (
    <Container fluid className="p-3">
      <h2>Pipelines</h2>
      <CardDeck className="mt-4">
        <NewPipelineCard onCreate={() => navigate('/pipelines/new')} />
        <WaitForData
          data={pipelinesFetcher.value}
          status={pipelinesFetcher.status}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty title="Couldn't load available pipelines" onRetry={pipelinesFetcher.refresh} />
          }
        >
          {(pipelines) => (
            <>
              {pipelines.map((pipeline, index) => (
                <React.Fragment key={`fragment-${index}`}>
                  {index % 2 ? <div className="w-100 d-none d-md-block" /> : null}
                  <PipelineCard
                    pipeline={pipeline}
                    onInstantiate={() => {
                      navigate(`/flows/new?pipelineId=${pipeline.name}`);
                    }}
                    showLink={`/pipelines/${pipeline.name}/edit`}
                  />
                  {index === pipelines.length - 1 && pipelines.length % 2 === 0 ? (
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
