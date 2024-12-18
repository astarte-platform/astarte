// Copyright 2020-2021 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import React, { Component } from "react";
import { Col, ListGroup, Row } from "react-bootstrap";
import { getSensorValueById } from "../apiHandler";
import Plot from "react-plotly.js";

const _ = require("lodash");

function SensorValue(props) {
  return (
    <ListGroup.Item className="border-0 py-2 px-3">
      <strong> {props.label}: </strong>
      {props.value} {props.unit}
    </ListGroup.Item>
  );
}

function SensorGraph(props) {
  const graphData = props.graphdata;
  return (
    <Col sm={10} xs={10}>
      <Plot
        data={[
          {
            x: graphData.map((item) => item.timestamp),
            y: graphData.map((item) => item.value),
            type: "scatter",
            mode: "lines+markers",
            marker: { color: "#6aa8d8" },
          },
        ]}
        layout={{ width: 865, height: 500 }}
      />
    </Col>
  );
}

class GraphComponent extends Component {
  state = {
    graphData: [],
    min: null,
    max: null,
    avg: null,
  };

  componentDidMount() {
    this.fetch();
  }

  setGraphValues(data) {
    const values = data.map((data) => data["value"]);
    this.setState({
      graphData: data,
      min: _.min(values).toFixed(4),
      max: _.max(values).toFixed(4),
      avg: _.round(_.meanBy(values), 2),
    });
  }

  fetch() {
    const { deviceID, interfaces, currentSensor } = this.props;
    getSensorValueById(deviceID, interfaces, currentSensor).then((response) => {
      const data = _.takeRight(response.data.data, 1000);
      this.setGraphValues(data);
    });
  }

  render() {
    const { graphData, min, max, avg } = this.state;
    const { currentSensor, availableSensors } = this.props;
    const sensor_values = [
      {
        label: "Max",
        value: max,
        unit: _.get(availableSensors, "unit"),
      },
      {
        label: "Min",
        value: min,
        unit: _.get(availableSensors, "unit"),
      },
      {
        label: "Avg",
        value: avg,
        unit: _.get(availableSensors, "unit"),
      },
    ];
    return (
      <div className="main-card bg-white py-5">
        <Row className="m-0">
          <Col xs={12} className="device-status-div px-4 ml-2 mb-2 pb-4">
            <h6 className="m-0 font-weight-bold position-relative">
              {currentSensor}
            </h6>
          </Col>
          <SensorGraph graphdata={graphData} />
          <Col sm={2} xs={2} className="list-div-main pt-3">
            <ListGroup>
              {sensor_values.map((item, index) => (
                <SensorValue
                  key={index}
                  label={item.label}
                  value={item.value}
                  unit={item.unit}
                />
              ))}
            </ListGroup>
          </Col>
        </Row>
      </div>
    );
  }
}

export default GraphComponent;
