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
import {
  Button,
  Col,
  Form,
  Row
} from "react-bootstrap";

import SingleCardPage from "./ui/SingleCardPage.js";

export default class NewPipelinePage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.addAlert = this.addAlert.bind(this);
    this.closeAlert = this.closeAlert.bind(this);
    this.onNameChanged = this.onNameChanged.bind(this);
    this.onSourceChanged = this.onSourceChanged.bind(this);
    this.onDescriptionChanged = this.onDescriptionChanged.bind(this);
    this.createPipeline = this.createPipeline.bind(this);

    this.state = {
      alerts: new Map(),
      alertId: 0,
      pipelineName: "",
      pipelineSource: "",
      pipelineDescription: ""
    };
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

  createPipeline(e) {
    const { pipelineName, pipelineSource, pipelineDescription } = this.state;

    this.astarte.registerPipeline({
      name: pipelineName,
      source: pipelineSource,
      description: pipelineDescription
    })
      .then(() => { this.props.history.push("/pipelines") })
      .catch((err) => {
        this.addAlert(`Couldn't create pipeline: ${err.message}`);
      });
  }

  isValidForm() {
    const { pipelineName, pipelineSource, pipelineDescription } = this.state;

    return (pipelineName != ""
        && pipelineName != "new"
        && pipelineSource != ""
    );
  }

  onNameChanged(e) {
    const newVal = e.target.value;
    this.setState({
        pipelineName: newVal
    });
  }

  onSourceChanged(e) {
    const newVal = e.target.value;
    this.setState({
        pipelineSource: newVal
    });
  }

  onDescriptionChanged(e) {
    const newVal = e.target.value;
    this.setState({
      pipelineDescription: newVal
    });
  }

  render() {
    const { alerts, pipelineName, pipelineSource, pipelineDescription } = this.state;

    return (
      <SingleCardPage
        title="New Pipeline"
        errorMessages={alerts}
        onAlertClose={this.closeAlert}
      >
        <Form>
          <Form.Group controlId="pipeline-name">
            <Form.Label>Name</Form.Label>
            <Form.Control
              type="text"
              value={pipelineName}
              onChange={this.onNameChanged}
            />
          </Form.Group>
          <Form.Group controlId="pipeline-source">
            <Form.Label>Source</Form.Label>
            <Form.Control
              as="textarea"
              rows={12}
              value={pipelineSource}
              onChange={this.onSourceChanged}
            />
          </Form.Group>
          <Form.Group controlId="pipeline-description">
            <Form.Label>Description</Form.Label>
            <Form.Control
              as="textarea"
              value={pipelineDescription}
              onChange={this.onDescriptionChanged}
            />
          </Form.Group>
        </Form>
        <Button
          variant="primary"
          onClick={this.createPipeline}
        >
          Create new pipeline
        </Button>
      </SingleCardPage>
    );
  }
}
