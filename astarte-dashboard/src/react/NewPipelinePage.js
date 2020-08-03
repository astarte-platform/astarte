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

import React, { useCallback, useMemo, useState } from "react";
import {
  Button,
  Col,
  Form,
  Row,
  Spinner
} from "react-bootstrap";
import Ajv from 'ajv';

import SingleCardPage from "./ui/SingleCardPage.js";

let alertId = 0;
const ajv = new Ajv({schemaId: 'id'});
ajv.addMetaSchema(require('ajv/lib/refs/json-schema-draft-04.json'));

export default ({ astarte, history }) => {
  const [alerts, setAlerts] = useState(new Map());
  const [isCreatingPipeline, setIsCreatingPipeline] = useState(false);
  const [pipeline, setPipeline] = useState({
    name: "",
    description: "",
    source: "",
    schema: ""
  });

  const addAlert = useCallback(
    (message) => {
      alertId += 1;
      setAlerts((alerts) => {
        const newAlerts = new Map(alerts);
        newAlerts.set(alertId, message);
        return newAlerts;
      });
    },
    [setAlerts]
  );

  const closeAlert = useCallback(
    (alertId) => {
      setAlerts((alerts) => {
        const newAlerts = new Map(alerts);
        newAlerts.delete(alertId);
        return newAlerts;
      });
    },
    [setAlerts]
  );

  const createPipeline = useCallback(() => {
    setIsCreatingPipeline(true);

    const pipelineParams = {
      name: pipeline.name,
      source: pipeline.source,
      description: pipeline.description
    };

    if (schemaObject) {
      pipelineParams.schema = schemaObject;
    }

    astarte
      .registerPipeline(pipelineParams)
      .then(() => history.push('/pipelines'))
      .catch((err) => {
        setIsCreatingPipeline(false);
        addAlert(`Couldn't create pipeline: ${err.message}`);
      });
  }, [astarte, history, setIsCreatingPipeline, addAlert, pipeline, schemaObject]);

  const schemaObject = useMemo(() => {
    if (pipeline.schema === '') {
      return undefined;
    }
    try {
      const schema = JSON.parse(pipeline.schema);
      return schema;
    } catch (e) {
      return undefined;
    }
  }, [pipeline.schema]);

  const isValidSchema = useMemo(() => {
    if (!schemaObject) {
      return false;
    }
    try {
      ajv.compile(schemaObject);
      return true;
    } catch (e) {
      return false;
    }
  }, [schemaObject, ajv]);

  const isValidPipelineName = pipeline.name !== '' && pipeline.name !== 'new';
  const isValidSource = pipeline.source !== '';
  const isValidForm = isValidPipelineName && isValidSource;

  return (
    <SingleCardPage
      title="New Pipeline"
      errorMessages={alerts}
      onAlertClose={closeAlert}
    >
      <Form>
        <Form.Group controlId="pipeline-name">
          <Form.Label>Name</Form.Label>
          <Form.Control
            type="text"
            value={pipeline.name}
            onChange={(e) => setPipeline({ ...pipeline, name: e.target.value})}
          />
        </Form.Group>
        <Form.Group controlId="pipeline-description">
          <Form.Label>Description</Form.Label>
          <Form.Control
            as="textarea"
            value={pipeline.description}
            onChange={(e) => setPipeline({ ...pipeline, description: e.target.value})}
          />
        </Form.Group>
        <Form.Group controlId="pipeline-source">
          <Form.Label>Source</Form.Label>
          <Form.Control
            as="textarea"
            rows={8}
            value={pipeline.source}
            onChange={(e) => setPipeline({ ...pipeline, source: e.target.value})}
          />
        </Form.Group>
        <Form.Group controlId="pipeline-schema">
          <Form.Label>Schema</Form.Label>
          <Form.Control
            as="textarea"
            rows={8}
            value={pipeline.schema}
            isValid={pipeline.schema !== '' && isValidSchema}
            isInvalid={pipeline.schema !== '' && !isValidSchema}
            onChange={(e) => setPipeline({ ...pipeline, schema: e.target.value})}
          />
        </Form.Group>
      </Form>
      <Button
        variant="primary"
        onClick={createPipeline}
        disabled={!isValidForm || isCreatingPipeline}
      >
        {isCreatingPipeline && (
          <Spinner
            as="span"
            size="sm"
            animation="border"
            role="status"
            className={"mr-2"}
          />
        )}
        Create new pipeline
      </Button>
    </SingleCardPage>
  );
}
