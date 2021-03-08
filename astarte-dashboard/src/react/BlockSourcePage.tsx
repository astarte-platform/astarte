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
import { AstarteCustomBlock } from 'astarte-client';

import { useAlerts } from './AlertManager';
import Empty from './components/Empty';
import ConfirmModal from './components/modals/Confirm';
import SingleCardPage from './ui/SingleCardPage';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import { useAstarte } from './AstarteManager';

const blockTypeToLabel = {
  consumer: 'Consumer',
  producer: 'Producer',
  producer_consumer: 'Producer & Consumer',
};

export default (): React.ReactElement => {
  const { blockId } = useParams();
  const astarte = useAstarte();
  const blockFetcher = useFetch(() => astarte.client.getBlock(blockId));
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeletingBlock, setIsDeletingBlock] = useState(false);
  const deletionAlerts = useAlerts();
  const navigate = useNavigate();

  const deleteBlock = useCallback(() => {
    setIsDeletingBlock(true);
    astarte.client
      .deleteBlock(blockId)
      .then(() => navigate('/blocks'))
      .catch((err: Error) => {
        setIsDeletingBlock(false);
        deletionAlerts.showError(`Couldn't delete block: ${err.message}`);
        setShowDeleteModal(false);
      });
  }, [astarte.client, navigate, setIsDeletingBlock, blockId, deletionAlerts.showError]);

  return (
    <>
      <SingleCardPage title="Block Details" backLink="/blocks">
        <deletionAlerts.Alerts />
        <WaitForData
          data={blockFetcher.value}
          status={blockFetcher.status}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty title="Couldn't load block source" onRetry={blockFetcher.refresh} />
          }
        >
          {(block) => (
            <Row>
              <Col>
                <h5 className="mt-2 mb-2">Name</h5>
                <p>{block.name}</p>
                <h5 className="mt-2 mb-2">Type</h5>
                <p>{blockTypeToLabel[block.type]}</p>
                {block instanceof AstarteCustomBlock && (
                  <>
                    <h5 className="mt-2 mb-2">Source</h5>
                    <SyntaxHighlighter language="json" showLineNumbers>
                      {block.source}
                    </SyntaxHighlighter>
                  </>
                )}
                <h5 className="mt-2 mb-2">Schema</h5>
                <SyntaxHighlighter language="json" showLineNumbers>
                  {JSON.stringify(block.schema, null, 2)}
                </SyntaxHighlighter>
              </Col>
            </Row>
          )}
        </WaitForData>
      </SingleCardPage>
      {blockFetcher.status === 'ok' && blockFetcher.value instanceof AstarteCustomBlock && (
        <Row className="justify-content-end m-3">
          <Button
            variant="danger"
            onClick={() => setShowDeleteModal(true)}
            disabled={isDeletingBlock}
          >
            {isDeletingBlock && (
              <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
            )}
            Delete block
          </Button>
        </Row>
      )}
      {showDeleteModal && (
        <ConfirmModal
          title="Warning"
          confirmLabel="Remove"
          confirmVariant="danger"
          onCancel={() => setShowDeleteModal(false)}
          onConfirm={deleteBlock}
          isConfirming={isDeletingBlock}
        >
          <p>
            Delete block <b>{blockId}</b>?
          </p>
        </ConfirmModal>
      )}
    </>
  );
};
