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
import { Button, Col, Row, Spinner } from "react-bootstrap";
import SyntaxHighlighter from 'react-syntax-highlighter';

import SingleCardPage from "./ui/SingleCardPage.js";

export default class PipelineSourcePage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.state = {
      alerts: new Map(),
      alertId: 0,
      phase: "loading"
    };

    this.addAlert = this.addAlert.bind(this);
    this.closeAlert = this.closeAlert.bind(this);
    this.handlePipelineResponse = this.handlePipelineResponse.bind(this);
    this.handlePipelineError = this.handlePipelineError.bind(this);
    this.deletePipeline = this.deletePipeline.bind(this);

    this.astarte
      .getPipelineSource(props.pipelineId)
      .then(this.handlePipelineResponse)
      .catch(this.handlePipelineError);
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

  deletePipeline() {
    this.astarte
      .deletePipeline(this.props.pipelineId)
      .then(this.props.history.push(`/pipelines`))
      .catch((err) => {
        this.addAlert(`Couldn't delete pipeline: ${err.message}`);
      });
  }

  handlePipelineResponse(response) {
    this.setState({
      phase: "ok",
      pipelineSource: response.data
    });
  }

  handlePipelineError(err) {
    console.log(err);
    this.setState({
      phase: "err",
      error: err
    });
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        const { name, source, description } = this.state.pipelineSource;

        innerHTML = (
          <>
          <Row>
            <Col>
              <h5 className="mt-2 mb-2">Name</h5>
              <p>{name}</p>
              <h5 className="mt-2 mb-2">Description</h5>
              <p>{description}</p>
              <h5 className="mt-2 mb-2">Source</h5>
              <SyntaxHighlighter language="text" showLineNumbers="true">
                {source}
              </SyntaxHighlighter>
            </Col>
          </Row>
          <Button
            variant="danger"
            onClick={this.deletePipeline}
          >
            Delete pipeline
          </Button>
          </>
        );
        break;

      case "err":
        innerHTML = <p>Couldn't load pipeline source</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return (
      <SingleCardPage
        title="Pipeline Details"
        errorMessages={this.state.alerts}
        onAlertClose={this.closeAlert}
      >
        {innerHTML}
      </SingleCardPage>
    );
  }
}
