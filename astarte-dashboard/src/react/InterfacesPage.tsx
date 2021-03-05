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

import React, { useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Badge, Button, Col, Container, ListGroup, Row, Spinner } from 'react-bootstrap';
import _ from 'lodash';

import { useAstarte } from './AstarteManager';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import useInterval from './hooks/useInterval';

interface InterfaceRowProps {
  name: string;
  majors: number[];
}

const InterfaceRow = ({ name, majors }: InterfaceRowProps): React.ReactElement => (
  <ListGroup.Item>
    <Container className="p-0" fluid>
      <Row>
        <Col>
          <Link to={`/interfaces/${name}/${Math.max(...majors)}/edit`}>
            <i className="fas fa-stream mr-2" />
            {name}
          </Link>
        </Col>
        <Col md="auto">
          {majors.map((major) => (
            <Link key={major} to={`/interfaces/${name}/${major}/edit`}>
              <Badge variant={major > 0 ? 'primary' : 'secondary'} className="mr-1 px-2 py-1">
                v{major}
              </Badge>
            </Link>
          ))}
        </Col>
      </Row>
    </Container>
  </ListGroup.Item>
);

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
    <Empty title="Couldn't load available interfaces" onRetry={onRetry} />
  </ListGroup.Item>
);

interface InterfaceInfo {
  name: string;
  majors: number[];
}

export default (): React.ReactElement => {
  const astarte = useAstarte();
  const navigate = useNavigate();

  const fetchInterfacesInfo = useCallback(async (): Promise<InterfaceInfo[]> => {
    const interfaceNames = await astarte.client.getInterfaceNames();
    const fetchedInterfaces = await Promise.all(
      interfaceNames.map((interfaceName) =>
        astarte.client.getInterfaceMajors(interfaceName).then((interfaceMajors) => ({
          name: interfaceName,
          majors: interfaceMajors.sort().reverse(),
        })),
      ),
    );
    const sortedInterfaces = _.sortBy(fetchedInterfaces, ['name']);
    return sortedInterfaces;
  }, [astarte.client]);

  const interfacesInfoFetcher = useFetch(fetchInterfacesInfo);

  useInterval(interfacesInfoFetcher.refresh, 30000);

  return (
    <Container fluid className="p-3">
      <Row>
        <Col>
          <h2>Interfaces</h2>
        </Col>
      </Row>
      <Row className="mt-3">
        <Col sm={12}>
          <ListGroup>
            <ListGroup.Item>
              <Button variant="link" className="p-0" onClick={() => navigate('/interfaces/new')}>
                <i className="fas fa-plus mr-2" />
                Install a new interface...
              </Button>
            </ListGroup.Item>
            <WaitForData
              data={interfacesInfoFetcher.value}
              status={interfacesInfoFetcher.status}
              fallback={<LoadingRow />}
              errorFallback={<ErrorRow onRetry={interfacesInfoFetcher.refresh} />}
            >
              {(interfaces) => (
                <>
                  {interfaces.map(({ name, majors }) => (
                    <InterfaceRow key={name} name={name} majors={majors} />
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
