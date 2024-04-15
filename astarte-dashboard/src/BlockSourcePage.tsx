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

import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Col, Container, Row, Spinner } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter';
import { AstarteCustomBlock } from 'astarte-client';
import _ from 'lodash';

import { actions, useStoreDispatch, useStoreSelector } from './store';
import { AlertsBanner, useAlerts } from './AlertManager';
import Empty from './components/Empty';
import ConfirmModal from './components/modals/Confirm';
import SingleCardPage from './ui/SingleCardPage';
import WaitForData from './components/WaitForData';

const blockTypeToLabel = {
  consumer: 'Consumer',
  producer: 'Producer',
  producer_consumer: 'Producer & Consumer',
};

export default (): React.ReactElement => {
  const { blockId = '' } = useParams();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletionAlerts, deletionAlertsController] = useAlerts();
  const navigate = useNavigate();
  const dispatch = useStoreDispatch();
  const blockData = useStoreSelector((selectors) => selectors.block(blockId));
  const blockStatus = useStoreSelector((selectors) => selectors.blockStatus(blockId));
  const isDeletingBlock = useStoreSelector((selectors) => selectors.isDeletingBlock(blockId));

  useEffect(() => {
    dispatch(actions.blocks.get(blockId));
  }, [dispatch, blockId]);

  const deleteBlock = useCallback(() => {
    dispatch(actions.blocks.delete(blockId)).then((action) => {
      if (action.meta.requestStatus === 'fulfilled') {
        navigate('/blocks');
      } else {
        deletionAlertsController.showError(
          `Couldn't delete block: ${_.get(action, 'error.message')}`,
        );
        setShowDeleteModal(false);
      }
    });
  }, [dispatch, navigate, blockId, deletionAlertsController]);

  return (
    <>
      <SingleCardPage title="Block Details" backLink="/blocks">
        <AlertsBanner alerts={deletionAlerts} />
        <WaitForData
          data={blockData}
          status={blockStatus}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty
              title="Couldn't load block source"
              onRetry={() => dispatch(actions.blocks.get(blockId))}
            />
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
      {blockStatus === 'ok' && blockData instanceof AstarteCustomBlock && (
        <div className="d-flex flex-column flex-md-row justify-content-end gap-3 m-3">
          <Button
            variant="danger"
            onClick={() => setShowDeleteModal(true)}
            disabled={isDeletingBlock}
          >
            {isDeletingBlock && (
              <Spinner as="span" size="sm" animation="border" role="status" className="me-2" />
            )}
            Delete block
          </Button>
        </div>
      )}
      {showDeleteModal && (
        <ConfirmModal
          title="Warning"
          confirmLabel="Delete"
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
