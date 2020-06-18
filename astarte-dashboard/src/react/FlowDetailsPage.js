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
import { Link } from "react-router-dom";
import { Button, Row, Spinner, Table } from "react-bootstrap";
import SyntaxHighlighter from 'react-syntax-highlighter';

import SingleCardPage from "./ui/SingleCardPage.js";

export default class FlowDetailsPage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.state = {
      phase: "loading"
    };

    this.handleFlowResponse = this.handleFlowResponse.bind(this);
    this.handleFlowError = this.handleFlowError.bind(this);

    this.astarte
      .getFlowDetails(props.flowName)
      .then(this.handleFlowResponse)
      .catch(this.handleFlowError);
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        const flow = this.state.flowDescription;

        innerHTML = (
          <>
          <h5>Flow configuration</h5>
          <SyntaxHighlighter language="json" showLineNumbers="true">
            {JSON.stringify(flow, null, 4)}
          </SyntaxHighlighter>
          </>
        );
        break;

      case "err":
        innerHTML = <p>Couldn't load flow description</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return (
      <SingleCardPage title="Flow Details">
        {innerHTML}
      </SingleCardPage>
    );
  }

  handleFlowResponse(response) {
    this.setState({
      phase: "ok",
      flowDescription: response.data
    });
  }

  handleFlowError(err) {
    console.log(err);
    this.setState({
      phase: "err",
      error: err
    });
  }
}
