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
import { useParams } from 'react-router-dom';
import { Container, Spinner } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter';

import SingleCardPage from './ui/SingleCardPage';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import { useAstarte } from './AstarteManager';

export default (): React.ReactElement => {
  const { flowName } = useParams();
  const astarte = useAstarte();
  const flowFetcher = useFetch(() => astarte.client.getFlowDetails(flowName));

  return (
    <SingleCardPage title="Flow Details" backLink="/flows">
      <WaitForData
        data={flowFetcher.value}
        status={flowFetcher.status}
        fallback={
          <Container fluid className="text-center">
            <Spinner animation="border" role="status" />
          </Container>
        }
        errorFallback={
          <Empty title="Couldn't load flow description" onRetry={flowFetcher.refresh} />
        }
      >
        {(flow) => (
          <>
            <h5>Flow configuration</h5>
            <SyntaxHighlighter language="json" showLineNumbers>
              {JSON.stringify(flow, null, 4)}
            </SyntaxHighlighter>
          </>
        )}
      </WaitForData>
    </SingleCardPage>
  );
};
