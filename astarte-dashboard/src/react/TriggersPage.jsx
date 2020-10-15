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
import { Button, Col, Container, ListGroup, Row, Spinner } from 'react-bootstrap';

const TriggerRow = ({ name, onClick }) => (
  <ListGroup.Item>
    <Button variant="link" className="p-0" onClick={onClick}>
      <i className="fas fa-bolt mr-2" />
      {name}
    </Button>
  </ListGroup.Item>
);

const LoadingRow = () => (
  <ListGroup.Item>
    <Spinner animation="border" role="status" />
  </ListGroup.Item>
);

export default ({ history, astarte }) => {
  const [triggers, setTriggers] = useState(null);
  const fetchTriggers = () => astarte.getTriggerNames().then(setTriggers);

  useEffect(() => {
    fetchTriggers();
    const intervalId = setInterval(fetchTriggers, 30000);
    return () => clearInterval(intervalId);
  }, []);

  return (
    <Container fluid className="p-3">
      <Row>
        <Col>
          <h2>Triggers</h2>
        </Col>
      </Row>
      <Row className="mt-3">
        <Col sm={12}>
          <ListGroup>
            <ListGroup.Item>
              <Button variant="link" className="p-0" onClick={() => history.push('/triggers/new')}>
                <i className="fas fa-plus mr-2" />
                Install a new trigger...
              </Button>
            </ListGroup.Item>
            {triggers ? (
              triggers.map((trigger) => (
                <TriggerRow
                  key={trigger}
                  name={trigger}
                  onClick={() => history.push(`/triggers/${trigger}`)}
                />
              ))
            ) : (
              <LoadingRow />
            )}
          </ListGroup>
        </Col>
      </Row>
    </Container>
  );
};
