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
import { Button, Form, Spinner } from "react-bootstrap";

import { useAlerts } from "./AlertManager";
import SingleCardPage from "./ui/SingleCardPage.js";

export default ({ astarte, history, pipelineId }) => {
  const [flow, setFlow] = useState({
    name: "",
    config: "{}",
  });
  const [isCreatingFlow, setIsCreatingFlow] = useState(false);

  const parsedFlowConfig = useMemo(() => {
    try {
      return JSON.parse(flow.config);
    } catch {
      return null;
    }
  }, [flow.config]);

  const formAlerts = useAlerts();

  const createFlow = useCallback(() => {
    setIsCreatingFlow(true);
    astarte
      .createNewFlowInstance({
        name: flow.name,
        config: parsedFlowConfig,
        pipeline: pipelineId,
      })
      .then(() => {
        history.push("/flows");
      })
      .catch((err) => {
        setIsCreatingFlow(false);
        formAlerts.showError(`Couldn't instantiate the Flow: ${err.message}`);
      });
  }, [
    setIsCreatingFlow,
    flow,
    parsedFlowConfig,
    pipelineId,
    astarte,
    history,
    formAlerts.showError,
  ]);

  const isValidFlowName = flow.name !== "";
  const isValidFlowConfig = parsedFlowConfig != null;
  const isValidForm = isValidFlowName && isValidFlowConfig;

  let innerHTML = (
    <Form>
      <Form.Group controlId="flow.name">
        <Form.Label>Name</Form.Label>
        <Form.Control
          type="text"
          placeholder="Your flow name"
          value={flow.name}
          onChange={(e) => setFlow({ ...flow, name: e.target.value })}
        />
      </Form.Group>
      <label>Pipeline ID</label>
      <p>
        <i>{pipelineId}</i>
      </p>
      <Form.Group controlId="flow.config">
        <Form.Label>Flow config</Form.Label>
        <Form.Control
          as="textarea"
          rows="12"
          value={flow.config}
          onChange={(e) => setFlow({ ...flow, config: e.target.value })}
        />
      </Form.Group>
      <Button
        variant="primary"
        disabled={!isValidForm || isCreatingFlow}
        onClick={createFlow}
      >
        {isCreatingFlow && (
          <Spinner
            className="mr-2"
            size="sm"
            animation="border"
            role="status"
          />
        )}
        Instantiate Flow
      </Button>
    </Form>
  );

  return (
    <SingleCardPage
      title="Flow Configuration"
      backLink="/pipelines"
    >
      <formAlerts.Alerts />
      {innerHTML}
    </SingleCardPage>
  );
};
