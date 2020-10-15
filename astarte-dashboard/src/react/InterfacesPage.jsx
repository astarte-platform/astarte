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
import { Link } from 'react-router-dom';
import { Badge, Button, Col, Container, ListGroup, Row, Spinner } from 'react-bootstrap';

const InterfaceRow = ({ name, majors }) => (
  <ListGroup.Item>
    <Container className="p-0" fluid>
      <Row>
        <Col>
          <Link to={`/interfaces/${name}/${Math.max(...majors)}`}>
            <i className="fas fa-stream mr-2" />
            {name}
          </Link>
        </Col>
        <Col md="auto">
          {majors.map((major) => (
            <Link key={major} to={`/interfaces/${name}/${major}`}>
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

const LoadingRow = () => (
  <ListGroup.Item>
    <Spinner animation="border" role="status" />
  </ListGroup.Item>
);

export default ({ history, astarte }) => {
  const [interfaces, setInterfaces] = useState(null);
  const fetchInterfaces = () =>
    astarte
      .getInterfaceNames()
      .then((result) => {
        const interfaceNames = result.sort();
        return Promise.all(
          interfaceNames.map((interfaceName) =>
            astarte.getInterfaceMajors(interfaceName).then((interfaceMajors) => ({
              name: interfaceName,
              majors: interfaceMajors.sort().reverse(),
            })),
          ),
        );
      })
      .then(setInterfaces);

  useEffect(() => {
    fetchInterfaces();
    const intervalId = setInterval(fetchInterfaces, 30000);
    return () => clearInterval(intervalId);
  }, []);

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
              <Button
                variant="link"
                className="p-0"
                onClick={() => history.push('/interfaces/new')}
              >
                <i className="fas fa-plus mr-2" />
                Install a new interface...
              </Button>
            </ListGroup.Item>
            {interfaces ? (
              interfaces.map(({ name, majors }) => (
                <InterfaceRow key={name} name={name} majors={majors} />
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
