/*
   This file is part of Astarte.

   Copyright 2023 SECO Mind Srl

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
import { useNavigate } from 'react-router-dom';
import { Button, Col, Container, ListGroup, Row, Spinner } from 'react-bootstrap';

import { useAstarte } from './AstarteManager';
import Empty from './components/Empty';
import Icon from './components/Icon';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import useInterval from './hooks/useInterval';

interface TriggerPolicyRowProps {
  name: string;
  onClick: () => void;
}

const TriggerPolicyRow = ({ name, onClick }: TriggerPolicyRowProps): React.ReactElement => {
  const astarte = useAstarte();
  return (
    <ListGroup.Item>
      {astarte.token?.can('realmManagement', 'GET', `/policies/${name}`) ? (
        <Button variant="link" className="p-0" onClick={onClick}>
          <Icon icon="policy" className="me-2" />
          {name}
        </Button>
      ) : (
        <>
          <Icon icon="policy" className="me-2" />
          {name}
        </>
      )}
    </ListGroup.Item>
  );
};

const LoadingRow = (): React.ReactElement => (
  <ListGroup.Item>
    <Container fluid className="text-center">
      <Spinner animation="border" role="status" />
    </Container>
  </ListGroup.Item>
);

interface ErrorRowProps {
  onRetry: () => void;
}

const ErrorRow = ({ onRetry }: ErrorRowProps): React.ReactElement => (
  <ListGroup.Item>
    <Empty title="Couldn't load available delivery policies" onRetry={onRetry} />
  </ListGroup.Item>
);

export default (): React.ReactElement => {
  const astarte = useAstarte();
  const navigate = useNavigate();
  const policiesFetcher = useFetch(astarte.client.getTriggerDeliveryPolicyNames);

  useInterval(policiesFetcher.refresh, 30000);

  return (
    <Container fluid className="p-3" data-testid="policies-page">
      <Row>
        <Col>
          <h2>Trigger Delivery Policies</h2>
        </Col>
      </Row>
      <Row className="mt-3">
        <Col sm={12}>
          <ListGroup>
            <ListGroup.Item>
              <Button
                variant="link"
                className="p-0"
                hidden={!astarte.token?.can('realmManagement', 'POST', '/policies')}
                onClick={() => {
                  navigate('/trigger-delivery-policies/new');
                }}
              >
                <Icon icon="add" className="me-2" />
                Install a new trigger delivery policy...
              </Button>
            </ListGroup.Item>
            <WaitForData
              data={policiesFetcher.value}
              status={policiesFetcher.status}
              fallback={<LoadingRow />}
              errorFallback={<ErrorRow onRetry={policiesFetcher.refresh} />}
            >
              {(policies) => (
                <>
                  {policies.map((policy) => (
                    <TriggerPolicyRow
                      key={policy}
                      name={policy}
                      onClick={() => {
                        navigate(`/trigger-delivery-policies/${policy}/edit`);
                      }}
                    />
                  ))}
                </>
              )}
            </WaitForData>
          </ListGroup>
        </Col>
      </Row>
    </Container>
  );
};
