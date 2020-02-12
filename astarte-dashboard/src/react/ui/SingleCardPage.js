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

import React from "react";
import { Alert, Container, Row, Col } from "react-bootstrap";

export default function SingleCardPage(props) {
  const { errorMessages, onAlertClose, children, title } = props;

  return (
    <Container fluid className="bg-white rounded pb-3 pt-2">
      { errorMessages &&
        <Row>
          { Array.from(errorMessages).map(([key, value]) =>
              <Col
                key={key}
                xs={12}
              >
                <ErrorAlert
                  alertId={key}
                  message={value}
                  onClose={() => onAlertClose(key)}
                />
              </Col>
            )
          }
        </Row>
      }
      <Row>
        <Col sm={12}>
          <h3>{title}</h3>
        </Col>
      </Row>
      <Row>
        <Col sm={12}>{children}</Col>
      </Row>
    </Container>
  );
}

function ErrorAlert(props) {
  return (
    <Alert
      variant="danger"
      onClose={() => props.onClose(props.alertId)}
      dismissible
    >
      {props.message}
    </Alert>
  );
}
