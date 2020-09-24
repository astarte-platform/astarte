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
import { Button, Col, Row, Spinner } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter';
import { AstarteCustomBlock } from 'astarte-client';

import { useAlerts } from './AlertManager';
import SingleCardPage from './ui/SingleCardPage';

const blockTypeToLabel = {
  consumer: 'Consumer',
  producer: 'Producer',
  producer_consumer: 'Producer & Consumer',
};

export default ({ astarte, history, blockId }) => {
  const [phase, setPhase] = useState('loading');
  const [block, setBlock] = useState(null);
  const [isDeletingBlock, setIsDeletingBlock] = useState(false);
  const deletionAlerts = useAlerts();

  const deleteBlock = useCallback(() => {
    setIsDeletingBlock(true);
    astarte
      .deleteBlock(blockId)
      .then(() => history.push('/blocks'))
      .catch((err) => {
        setIsDeletingBlock(false);
        deletionAlerts.showError(`Couldn't delete block: ${err.message}`);
      });
  }, [astarte, history, setIsDeletingBlock, blockId, deletionAlerts.showError]);

  useEffect(() => {
    astarte
      .getBlock(blockId)
      .then((fetchedBlock) => {
        setBlock(fetchedBlock);
        setPhase('ok');
      })
      .catch(() => setPhase('err'));
  }, [astarte, setBlock, setPhase]);

  const ContentCard = ({ children }) => (
    <SingleCardPage title="Block Details" backLink="/blocks">
      {children}
    </SingleCardPage>
  );

  switch (phase) {
    case 'ok':
      return (
        <>
          <ContentCard>
            <deletionAlerts.Alerts />
            <Row>
              <Col>
                <h5 className="mt-2 mb-2">Name</h5>
                <p>{block.name}</p>
                <h5 className="mt-2 mb-2">Type</h5>
                <p>{blockTypeToLabel[block.type]}</p>
                {block instanceof AstarteCustomBlock && (
                  <>
                    <h5 className="mt-2 mb-2">Source</h5>
                    <SyntaxHighlighter language="json" showLineNumbers="true">
                      {block.source}
                    </SyntaxHighlighter>
                  </>
                )}
                <h5 className="mt-2 mb-2">Schema</h5>
                <SyntaxHighlighter language="json" showLineNumbers="true">
                  {JSON.stringify(block.schema, null, 2)}
                </SyntaxHighlighter>
              </Col>
            </Row>
          </ContentCard>
          <Row className="justify-content-end m-3">
            {block instanceof AstarteCustomBlock && (
              <Button
                variant="danger"
                onClick={isDeletingBlock ? undefined : deleteBlock}
                disabled={isDeletingBlock}
              >
                {isDeletingBlock && (
                  <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
                )}
                Delete block
              </Button>
            )}
          </Row>
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
