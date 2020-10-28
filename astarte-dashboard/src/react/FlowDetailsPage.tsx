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
import { Spinner } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter';
import AstarteClient from 'astarte-client';

import SingleCardPage from './ui/SingleCardPage';
import useFetch from './hooks/useFetch';

interface Props {
  astarte: AstarteClient;
  flowName: string;
}

export default ({ astarte, flowName }: Props): React.ReactElement => {
  const flow = useFetch(() => astarte.getFlowDetails(flowName));

  let innerHTML;

  switch (flow.status) {
    case 'ok':
      innerHTML = (
        <>
          <h5>Flow configuration</h5>
          <SyntaxHighlighter language="json" showLineNumbers>
            {JSON.stringify(flow.value, null, 4)}
          </SyntaxHighlighter>
        </>
      );
      break;

    case 'err':
      innerHTML = <p>Couldn&apos;t load flow description</p>;
      break;

    default:
      innerHTML = <Spinner animation="border" role="status" />;
      break;
  }

  return (
    <SingleCardPage title="Flow Details" backLink="/flows">
      {innerHTML}
    </SingleCardPage>
  );
};
