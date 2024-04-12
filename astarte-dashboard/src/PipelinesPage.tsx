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
import { Button, Card, Col, Container, Row, Spinner } from 'react-bootstrap';
import type { AstartePipeline } from 'astarte-client';

import { useAstarte } from './AstarteManager';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';

interface NewPipelineCardProps {
  onCreate: () => void;
}

const NewPipelineCard = ({ onCreate }: NewPipelineCardProps): React.ReactElement => (
  <Card className="mb-4 h-100">
    <Card.Header as="h5">New Pipeline</Card.Header>
    <Card.Body className="d-flex flex-column">
      <Card.Text>Create your custom pipeline</Card.Text>
      <div className="mt-auto d-flex flex-column flex-md-row">
        <Button variant="secondary" onClick={onCreate}>
          Create
        </Button>
      </div>
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
  <Card className="mb-4 h-100">
    <Card.Header as="h5">
      <Link to={showLink}>{pipeline.name}</Link>
    </Card.Header>
    <Card.Body className="d-flex flex-column">
      <Card.Text>{pipeline.description}</Card.Text>
      <div className="mt-auto d-flex flex-column flex-md-row">
        <Button variant="primary" onClick={onInstantiate}>
          Instantiate
        </Button>
      </div>
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
      <Row xs={1} lg={2} xxl={3} className="mt-4 g-4">
        <Col>
          <NewPipelineCard onCreate={() => navigate('/pipelines/new')} />
        </Col>
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
              {pipelines.map((pipeline) => (
                <Col key={pipeline.name}>
                  <PipelineCard
                    pipeline={pipeline}
                    onInstantiate={() => {
                      navigate(`/flows/new?pipelineId=${pipeline.name}`);
                    }}
                    showLink={`/pipelines/${pipeline.name}/edit`}
                  />
                </Col>
              ))}
            </>
          )}
        </WaitForData>
      </Row>
    </Container>
  );
};
