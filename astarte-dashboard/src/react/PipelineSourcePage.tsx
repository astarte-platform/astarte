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
import { Button, Col, Row, Spinner } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter';
import AstarteClient from 'astarte-client';
import _ from 'lodash';

import { useAlerts } from './AlertManager';
import SingleCardPage from './ui/SingleCardPage';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';

interface Props {
  astarte: AstarteClient;
  history: any;
  pipelineId: string;
}

export default ({ astarte, history, pipelineId }: Props): React.ReactElement => {
  const pipelineFetcher = useFetch(() => astarte.getPipeline(pipelineId));
  const [isDeletingPipeline, setIsDeletingPipeline] = useState(false);
  const deletionAlerts = useAlerts();

  const deletePipeline = useCallback(() => {
    setIsDeletingPipeline(true);
    astarte
      .deletePipeline(pipelineId)
      .then(() => history.push('/pipelines'))
      .catch((err) => {
        deletionAlerts.showError(`Couldn't delete pipeline: ${err.message}`);
        setIsDeletingPipeline(false);
      });
  }, [astarte, pipelineId, history, deletionAlerts.showError]);

  return (
    <SingleCardPage title="Pipeline Details" backLink="/pipelines">
      <WaitForData
        data={pipelineFetcher.value}
        status={pipelineFetcher.status}
        fallback={<Spinner animation="border" role="status" />}
        errorFallback={<p>Couldn&apos;t load pipeline source</p>}
      >
        {(pipeline) => (
          <>
            <deletionAlerts.Alerts />
            <Row>
              <Col>
                <h5 className="mt-2 mb-2">Name</h5>
                <p>{pipeline.name}</p>
                {pipeline.description && (
                  <>
                    <h5 className="mt-2 mb-2">Description</h5>
                    <p>{pipeline.description}</p>
                  </>
                )}
                <h5 className="mt-2 mb-2">Source</h5>
                <SyntaxHighlighter language="text" showLineNumbers>
                  {pipeline.source}
                </SyntaxHighlighter>
                {!_.isEmpty(pipeline.schema) && (
                  <>
                    <h5 className="mt-2 mb-2">Schema</h5>
                    <SyntaxHighlighter language="json" showLineNumbers>
                      {JSON.stringify(pipeline.schema, null, 2)}
                    </SyntaxHighlighter>
                  </>
                )}
              </Col>
            </Row>
            <Button variant="danger" onClick={deletePipeline} disabled={isDeletingPipeline}>
              {isDeletingPipeline && (
                <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
              )}
              Delete pipeline
            </Button>
          </>
        )}
      </WaitForData>
    </SingleCardPage>
  );
};
