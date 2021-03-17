/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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
import { Button, Container } from 'react-bootstrap';

interface Props {
  title: string;
  onRetry?: () => void;
}

const Empty = ({ title, onRetry }: Props): React.ReactElement => {
  const tryAgain = onRetry ? (
    <Button variant="link" className="p-0" onClick={onRetry}>
      try again
    </Button>
  ) : (
    'try again'
  );

  return (
    <Container fluid className="text-center">
      <img
        src="/static/img/mascotte-repair.svg"
        alt="Lion mascotte with repair tools"
        style={{ maxWidth: 200 }}
      />
      <h5 className="mt-2">{title}</h5>
      <p>Please check your connectivity and {tryAgain}.</p>
    </Container>
  );
};

export default Empty;
