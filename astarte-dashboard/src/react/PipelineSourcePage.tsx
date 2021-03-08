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
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Col, Container, Row, Spinner } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter';
import _ from 'lodash';

import { useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import SingleCardPage from './ui/SingleCardPage';
import Empty from './components/Empty';
import ConfirmModal from './components/modals/Confirm';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';

export default (): React.ReactElement => {
  const { pipelineId } = useParams();
  const astarte = useAstarte();
  const pipelineFetcher = useFetch(() => astarte.client.getPipeline(pipelineId));
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeletingPipeline, setIsDeletingPipeline] = useState(false);
  const deletionAlerts = useAlerts();
  const navigate = useNavigate();

  const deletePipeline = useCallback(() => {
    setIsDeletingPipeline(true);
    astarte.client
      .deletePipeline(pipelineId)
      .then(() => navigate('/pipelines'))
      .catch((err) => {
        deletionAlerts.showError(`Couldn't delete pipeline: ${err.message}`);
        setIsDeletingPipeline(false);
        setShowDeleteModal(false);
      });
  }, [astarte.client, pipelineId, navigate, deletionAlerts.showError]);

  return (
    <>
      <SingleCardPage title="Pipeline Details" backLink="/pipelines">
        <deletionAlerts.Alerts />
        <WaitForData
          data={pipelineFetcher.value}
          status={pipelineFetcher.status}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty title="Couldn't load pipeline source" onRetry={pipelineFetcher.refresh} />
          }
        >
          {(pipeline) => (
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
          )}
        </WaitForData>
      </SingleCardPage>
      {pipelineFetcher.status === 'ok' && (
        <Row className="justify-content-end m-3">
          <Button
            variant="danger"
            onClick={() => setShowDeleteModal(true)}
            disabled={isDeletingPipeline}
          >
            {isDeletingPipeline && (
              <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
            )}
            Delete pipeline
          </Button>
        </Row>
      )}
      {showDeleteModal && (
        <ConfirmModal
          title="Warning"
          confirmLabel="Remove"
          confirmVariant="danger"
          onCancel={() => setShowDeleteModal(false)}
          onConfirm={deletePipeline}
          isConfirming={isDeletingPipeline}
        >
          <p>
            Delete pipeline <b>{pipelineId}</b>?
          </p>
        </ConfirmModal>
      )}
    </>
  );
};
