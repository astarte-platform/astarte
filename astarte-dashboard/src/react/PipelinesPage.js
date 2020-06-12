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
import { CardDeck, Container, Spinner, Table } from "react-bootstrap";

import SingleCardPage from "./ui/SingleCardPage.js";
import PipelineCard from "./ui/PipelineCard.js";
import NewPipelineCard from "./ui/NewPipelineCard.js";

export default class PipelinesPage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.state = {
      phase: "loading"
    };

    this.redirectToConfiguration = this.redirectToConfiguration.bind(this);
    this.handlePipelinesResponse = this.handlePipelinesResponse.bind(this);
    this.handlePipelinesError = this.handlePipelinesError.bind(this);

    this.astarte
      .getPipelineDefinitions()
      .then(this.handlePipelinesResponse)
      .catch(this.handlePipelinesError);
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        innerHTML = (
          <CardDeck className="mt-4">
            <NewPipelineCard
              onCreate={() =>
                this.props.history.push(`/pipelines/new`)
              }
            />
            {this.state.pipelines.map((pipeline, index) => {
              return (
                <React.Fragment key={`fragment-${index}`}>
                  {index % 2 ? (
                    <div className="w-100 d-none d-md-block" />
                  ) : null}
                  <PipelineCard
                    headless="true"
                    pipelineName={pipeline.name}
                    pipelineDescription={pipeline.description}
                    pipelineLongDescription={pipeline.longDescription}
                    configureCB={() =>
                      this.props.history.push(`/flows/new/${pipeline.name}`)
                    }
                    onShow={() =>
                      this.props.history.push(`/pipelines/${pipeline.name}`)
                    }
                  />
                  {index == this.state.pipelines.length - 1 &&
                  this.state.pipelines.length % 2 == 0 ? (
                    <div className="w-50 d-none d-md-block" />
                  ) : null}
                </React.Fragment>
              );
            })}
          </CardDeck>
        );
        break;

      case "err":
        innerHTML = <p>Couldn't load avalilable pipelines</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return (
      <Container fluid className="p-3">
        <h2>Pipelines</h2>
        {innerHTML}
      </Container>
    );
  }

  redirectToConfiguration(pipelineId) {
    this.props.history.push(`/flows/new/${pipelineId}`);
  }

  handlePipelinesResponse(response) {
    const pipelineList = response.data;
    const promiseList = pipelineList.map((pipelineName) =>
      this.astarte.getPipelineInputConfig(pipelineName)
    );

    Promise.allSettled(promiseList)
      .then((result) => {
        let pipelineData = [];

        for (let pipelineResult of result) {
          if (pipelineResult.status == "fulfilled") {
            pipelineData.push(pipelineResult.value.data);
          }
        }

        this.setState({
          phase: "ok",
          pipelines: pipelineData
        });
      });
  }

  handlePipelinesError(err) {
    this.setState({
      phase: "err",
      error: err
    });
  }
}
