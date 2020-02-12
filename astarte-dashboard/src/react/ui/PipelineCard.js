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
import Button from "react-bootstrap/Button";
import Card from "react-bootstrap/Card";

export default function PipelineCard(props) {
  if (props.headless) {
    return headless(props);
  } else {
    return normal(props);
  }
}

function normal(props) {
  return (
    <Card>
      <Card.Header as="h5">{props.pipelineName}</Card.Header>
      <Card.Body>
        <Card.Title>{props.pipelineDescription}</Card.Title>
        <Card.Text>{props.pipelineLongDescription}</Card.Text>
        <Button variant="primary" onClick={props.configureCB}>
          Instantiate
        </Button>
      </Card.Body>
    </Card>
  );
}

function headless(props) {
  return (
    <Card className="mb-2">
      <Card.Body>
        <Card.Title>{props.pipelineName}</Card.Title>
        <Card.Subtitle className="mb-2 text-muted">
          {props.pipelineDescription}
        </Card.Subtitle>
        <Card.Text>{props.pipelineLongDescription}</Card.Text>
      </Card.Body>
      <Card.Footer className="d-flex flex-row-reverse">
        <Button variant="primary" onClick={props.configureCB}>
          Instantiate
        </Button>
        <Button variant="secondary" className="mx-1" onClick={props.onShow}>
          Show
        </Button>
      </Card.Footer>
    </Card>
  );
}
