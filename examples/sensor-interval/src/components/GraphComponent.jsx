import React, { Component } from "react";
import { Col, ListGroup, Form, Card } from "react-bootstrap";
import { getSensorValueById, getAvailableSensors } from "../apiHandler";
import Plot from "react-plotly.js";
import DateSelectComponent from "./DateSelectComponent";

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
  const { graphdata, startDate, endDate } = props;

  if (graphdata === 0) {
    return <Col sm={10} xs={10}></Col>;
  }

  return (
    <Col sm={10} xs={10}>
      <Plot
        data={[
          {
            x: graphdata.map((item) => item.timestamp),
            y: graphdata.map((item) => item.value),
            type: "scatter",
            mode: "lines+markers",
            marker: { color: "#6aa8d8" },
          },
        ]}
        layout={{
          width: 865,
          height: 500,
          xaxis: {
            title: "Date",
            range: [startDate, endDate],
          },
        }}
      />
    </Col>
  );
}

class GraphComponent extends Component {
  constructor(props) {
    super(props);
    this.state = {
      graphData: [],
      min: null,
      max: null,
      avg: null,
      selectedInterval: 1000,
      selectedSensor: "",
      availableSensors: [],
      startDate: new Date(Date.now() - 86400 * 1000),
      endDate: new Date(),
      isDateRangeSelected: false,
    };
    this.onDateChange = this.onDateChange.bind(this);
  }

  onDateChange(dates) {
    const [start, end] = dates;
    this.setState({
      startDate: start,
      endDate: end,
      isDateRangeSelected: true,
      graphData: [],
      min: 0,
      max: 0,
      avg: 0,
    });
  }

  handleSensorChange = (event) => {
    const newSensor = event.target.value;
    if (newSensor === "") {
      this.setState({
        selectedSensor: newSensor,
        graphData: [],
        min: 0,
        max: 0,
        avg: 0,
      });
    } else {
      this.setState({ selectedSensor: newSensor }, () => {
        this.fetchAvailableSensors();
      });
    }
  };

  setAvailableSensors(data) {
    this.setState({ availableSensors: data });
  }

  fetchAvailableSensors() {
    const { deviceID, interfaces } = this.props;
    getAvailableSensors(deviceID, interfaces)
      .then((availableSensors) => {
        this.setAvailableSensors(availableSensors);
        this.fetch();
      })
      .catch((error) => {
        console.error("Error fetching available sensors:", error);
      });
  }

  setGraphValues(data) {
    const { startDate, endDate } = this.state;
    if (data.length === 0) {
      this.setState({
        graphData: [],
        min: 0,
        max: 0,
        avg: 0,
      });
      return;
    }
    const dataInRange = data.filter(
      (item) =>
        new Date(item.timestamp) >= startDate &&
        new Date(item.timestamp) <= endDate
    );
    const valuesInRange = dataInRange.map((item) => item.value);
    const minInRange =
      valuesInRange.length > 0 ? _.min(valuesInRange).toFixed(4) : 0;
    const maxInRange =
      valuesInRange.length > 0 ? _.max(valuesInRange).toFixed(4) : 0;
    const avgInRange =
      valuesInRange.length > 0 ? _.round(_.meanBy(valuesInRange), 2) : 0;
    this.setState({
      graphData: dataInRange,
      min: minInRange,
      max: maxInRange,
      avg: avgInRange,
    });
  }

  fetch() {
    const { deviceID, interfaces, currentSensor } = this.props;
    const { startDate, endDate } = this.state;
    const startOfDay = new Date(startDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(endDate);
    endOfDay.setHours(23, 59, 59, 999);

    getSensorValueById(
      deviceID,
      interfaces,
      currentSensor,
      startOfDay,
      endOfDay
    ).then((response) => {
      const data = _.takeRight(response.data.data, 1000);
      this.setGraphValues(data);
    });
  }

  handleDateSubmit = () => {
    this.fetch();
  };

  render() {
    const {
      graphData,
      min,
      max,
      avg,
      selectedSensor,
      startDate,
      endDate,
      isDateRangeSelected,
    } = this.state;
    const { currentSensor, availableSensors } = this.props;
    const isSensorSelected = selectedSensor !== "";
    const sensorOptions = (
      <option key={availableSensors.name} value={availableSensors.name}>
        {availableSensors.name}
      </option>
    );
    return (
      <div className="main-card bg-white py-5">
        <div className="px-3">
          <span>Select a Sensor: </span>
          <select
            className="bg-white font-weight-normal rounded text-center"
            value={selectedSensor}
            onChange={this.handleSensorChange}
          >
            <option value="">Select a sensor</option>
            {sensorOptions}
          </select>
        </div>
        <div className="px-3 py-3">
          <Col sm={6} xs={6} className="px-1 ml-2 mb-2 pb-4">
            {isSensorSelected && (
              <h6 className="m-0 font-weight-bold position-relative">
                {currentSensor}
              </h6>
            )}
          </Col>
          {isSensorSelected && (
            <Form.Group className="mb-3">
              <DateSelectComponent
                startDate={startDate}
                endDate={endDate}
                handleChange={this.onDateChange}
                placeholder={""}
              />
            </Form.Group>
          )}
          {isSensorSelected && isDateRangeSelected && (
            <button className="btn btn-primary" onClick={this.handleDateSubmit}>
              Submit
            </button>
          )}
        </div>
        {isSensorSelected && (
          <div className="sensor-values-card">
            <Card.Body>
              <ListGroup>
                <SensorValue
                  label="Max"
                  value={max}
                  unit={_.get(availableSensors, "unit")}
                />
                <SensorValue
                  label="Min"
                  value={min}
                  unit={_.get(availableSensors, "unit")}
                />
                <SensorValue
                  label="Avg"
                  value={avg}
                  unit={_.get(availableSensors, "unit")}
                />
              </ListGroup>
            </Card.Body>
          </div>
        )}
        <SensorGraph
          graphdata={graphData}
          startDate={startDate}
          endDate={endDate}
        />
      </div>
    );
  }
}

export default GraphComponent;
