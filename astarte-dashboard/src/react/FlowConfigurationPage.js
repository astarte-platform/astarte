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
import { Button, Form, Spinner } from "react-bootstrap";

import SingleCardPage from "./ui/SingleCardPage.js";

export default class FlowConfigurationPage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.addAlert = this.addAlert.bind(this);
    this.closeAlert = this.closeAlert.bind(this);
    this.onFlowNameChange = this.onFlowNameChange.bind(this);
    this.onConfigChange = this.onConfigChange.bind(this);
    this.createFlow = this.createFlow.bind(this);

    this.state = {
      alerts: new Map(),
      alertId: 0,
      flowName: "",
      config: "{}",
      parsedConfig: null
    }
  }

  addAlert(message) {
    this.setState((state) => {
      const newAlertId = state.alertId + 1;
      let newAlerts = state.alerts;
      newAlerts.set(newAlertId, message);

      return Object.assign(state, {
        alertId: newAlertId,
        alerts: newAlerts
      });
    });
  }

  closeAlert(alertId) {
    this.setState((state) => {
      state.alerts.delete(alertId);
      return state;
    });
  }

  onFlowNameChange(e) {
    const newValue = e.target.value;

    this.setState({
      flowName: newValue
    });
  }

  onConfigChange(e) {
    const newValue = e.target.value;
    let parsedConfig;

    try {
      parsedConfig = JSON.parse(newValue);
    } catch (e) {
      parsedConfig = null;
    }

    this.setState({
      config: newValue,
      parsedConfig: parsedConfig
    });
  }

  createFlow() {
    const { flowName, parsedConfig } = this.state;

    this.astarte
      .createNewFlowInstance({
        config: parsedConfig,
        name: flowName,
        pipeline: this.props.pipelineId
      })
      .then(() => { this.props.history.push("/flows") })
      .catch((err) => {
        this.addAlert(`Couldn't instantiate the Flow: ${err.message}`);
      });
  }

  render() {
    const { alerts, flowName, config, parsedConfig } = this.state;
    let innerHTML = (
      <Form>
        <Form.Group controlId="flow.name">
          <Form.Label>Name</Form.Label>
          <Form.Control
            type="text"
            placeholder="Your flow name"
            value={flowName}
            onChange={this.onFlowNameChange}
          />
        </Form.Group>
        <label>Pipeline ID</label>
        <p>
          <i>{this.props.pipelineId}</i>
        </p>
        <Form.Group controlId="flow.config">
          <Form.Label>Flow config</Form.Label>
          <Form.Control
            as="textarea"
            rows="12"
            value={config}
            onChange={this.onConfigChange}
          />
        </Form.Group>
        <Button
          variant="primary"
          disabled={parsedConfig == null || flowName == ""}
          onClick={this.createFlow}
        >
          Instantiate Flow
        </Button>
      </Form>
    );

    return (
      <SingleCardPage
        title="Flow Configuration"
        backLink="/pipelines"
        errorMessages={alerts}
        onAlertClose={this.closeAlert}
      >
        {innerHTML}
      </SingleCardPage>
    );
  }
}
