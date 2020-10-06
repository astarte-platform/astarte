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

import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Button, Card, CardDeck, Container, Spinner } from 'react-bootstrap';

export default ({ astarte, history }) => {
  const [phase, setPhase] = useState('loading');
  const [pipelines, setPipelines] = useState(null);

  useEffect(() => {
    const handlePipelinesResponse = (pipelineList) => {
      const promiseList = pipelineList.map((pipelineName) =>
        astarte.getPipelineInputConfig(pipelineName),
      );
      Promise.allSettled(promiseList).then((result) => {
        const pipelineData = [];
        result.forEach((pipelineResult) => {
          if (pipelineResult.status === 'fulfilled') {
            pipelineData.push(pipelineResult.value);
          }
        });
        setPipelines(pipelineData);
        setPhase('ok');
      });
    };
    const handlePipelinesError = () => {
      setPhase('err');
    };
    astarte.getPipelineDefinitions().then(handlePipelinesResponse).catch(handlePipelinesError);
  }, [astarte]);

  let innerHTML;

  switch (phase) {
    case 'ok':
      innerHTML = (
        <CardDeck className="mt-4">
          <NewPipelineCard onCreate={() => history.push('/pipelines/new')} />
          {pipelines.map((pipeline, index) => (
            <React.Fragment key={`fragment-${index}`}>
              {index % 2 ? <div className="w-100 d-none d-md-block" /> : null}
              <PipelineCard
                headless="true"
                pipelineName={pipeline.name}
                pipelineDescription={pipeline.description}
                pipelineLongDescription={pipeline.longDescription}
                configureCB={() => history.push(`/flows/new/${pipeline.name}`)}
                onShow={() => history.push(`/pipelines/${pipeline.name}`)}
              />
              {index === pipelines.length - 1 && pipelines.length % 2 === 0 ? (
                <div className="w-50 d-none d-md-block" />
              ) : null}
            </React.Fragment>
          ))}
        </CardDeck>
      );
      break;

    case 'err':
      innerHTML = <p>Couldn&apos;t load avalilable pipelines</p>;
      break;

    default:
      innerHTML = <Spinner animation="border" role="status" />;
      break;
  }

  return (
    <Container fluid className="p-3">
      <h2>Pipelines</h2>
      {innerHTML}
    </Container>
  );
};

const NewPipelineCard = ({ onCreate }) => (
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

const PipelineCard = ({ pipelineName, pipelineDescription, configureCB }) => (
  <Card className="mb-4">
    <Card.Header as="h5">
      <Link to={`/pipelines/${pipelineName}`}>{pipelineName}</Link>
    </Card.Header>
    <Card.Body>
      <Card.Text>{pipelineDescription}</Card.Text>
      <Button variant="primary" onClick={configureCB}>
        Instantiate
      </Button>
    </Card.Body>
  </Card>
);
