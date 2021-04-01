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

import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Col, Row, Spinner } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter';
import AstarteClient, { AstarteCustomBlock } from 'astarte-client';
import type { AstarteBlock } from 'astarte-client';

import { useAlerts } from './AlertManager';
import ConfirmModal from './components/modals/Confirm';
import SingleCardPage from './ui/SingleCardPage';

const blockTypeToLabel = {
  consumer: 'Consumer',
  producer: 'Producer',
  producer_consumer: 'Producer & Consumer',
};

interface Props {
  astarte: AstarteClient;
  blockId: AstarteBlock['name'];
}

export default ({ astarte, blockId }: Props): React.ReactElement => {
  const [phase, setPhase] = useState('loading');
  const [block, setBlock] = useState<AstarteBlock | null>(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [isDeletingBlock, setIsDeletingBlock] = useState(false);
  const deletionAlerts = useAlerts();
  const navigate = useNavigate();

  const deleteBlock = useCallback(() => {
    setIsDeletingBlock(true);
    astarte
      .deleteBlock(blockId)
      .then(() => navigate('/blocks'))
      .catch((err: Error) => {
        setIsDeletingBlock(false);
        deletionAlerts.showError(`Couldn't delete block: ${err.message}`);
        setShowDeleteModal(false);
      });
  }, [astarte, navigate, setIsDeletingBlock, blockId, deletionAlerts.showError]);

  useEffect(() => {
    astarte
      .getBlock(blockId)
      .then((fetchedBlock) => {
        setBlock(fetchedBlock);
        setPhase('ok');
      })
      .catch(() => setPhase('err'));
  }, [astarte, setBlock, setPhase]);

  const ContentCard = ({ children }: { children: React.ReactNode }): React.ReactElement => (
    <SingleCardPage title="Block Details" backLink="/blocks">
      {children}
    </SingleCardPage>
  );

  switch (phase) {
    case 'ok':
      const blockObj = block as AstarteBlock;
      return (
        <>
          <ContentCard>
            <deletionAlerts.Alerts />
            <Row>
              <Col>
                <h5 className="mt-2 mb-2">Name</h5>
                <p>{blockObj.name}</p>
                <h5 className="mt-2 mb-2">Type</h5>
                <p>{blockTypeToLabel[blockObj.type]}</p>
                {blockObj instanceof AstarteCustomBlock && (
                  <>
                    <h5 className="mt-2 mb-2">Source</h5>
                    <SyntaxHighlighter language="json" showLineNumbers>
                      {blockObj.source}
                    </SyntaxHighlighter>
                  </>
                )}
                <h5 className="mt-2 mb-2">Schema</h5>
                <SyntaxHighlighter language="json" showLineNumbers>
                  {JSON.stringify(blockObj.schema, null, 2)}
                </SyntaxHighlighter>
              </Col>
            </Row>
          </ContentCard>
          <Row className="justify-content-end m-3">
            {blockObj instanceof AstarteCustomBlock && (
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
            )}
          </Row>
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

    case 'err':
      return (
        <ContentCard>
          <p>Couldn&apos;t load block source</p>
        </ContentCard>
      );

    default:
      return (
        <ContentCard>
          <Spinner animation="border" role="status" />
        </ContentCard>
      );
  }
};
