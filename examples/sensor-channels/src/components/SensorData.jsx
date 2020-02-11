import React from "react";
import { Alert, Col, Container, ListGroup, Row } from "react-bootstrap";

function ListItem(props) {
  return (
    <ListGroup.Item
      key={props.index}
      className="temperature-list px-3 border-0 pb-0 py-2 bg-transparent"
    >
      <b>{props.label}: </b>
      <span>{props.value}</span>
    </ListGroup.Item>
  );
}

const setSensorDataCard = (index, sensor) => {
  const sensor_item = [
    {
      label: "Value",
      value: sensor.value
    },
    {
      label: "Last Update",
      value: sensor.timestamp
    }
  ];
  return (
    <Row key={index} className="m-3 bg-light px-2 pt-3 pb-2">
      <Col className="text-dark px-3 py-2 bg-transparent border-0 w-100 text-left btn text-decoration-none">
        <span className="bg-sensor-theme font-weight-light py-2 px-3 w-100 text-white d-inline-block">
          <b className="m-0">Sensor Name : {sensor.name}</b>
        </span>
          <ListGroup className="py-1 my-2">
            {sensor_item.map((item, index) => (
              <ListItem key={index} label={item.label} value={item.value} />
            ))}
          </ListGroup>
      </Col>
    </Row>
  );
};

const ConnectionStatus = props => {
  const connection_type = props.connection_type;
  return (
    <Row className="m-3">
      <Col className="col-12 text-dark px-3 py-2 bg-transparent border-0 w-100 text-left btn text-decoration-none">
        <h6 className="m-0 font-weight-bold position-relative">
          Device Status : &nbsp;
          <span
            className={`status-tag rounded-circle d-inline-block mr-2 ${
              connection_type ? "connected" : "disconnected"
            }`}
          />
          {connection_type ? "Connected" : "Disconnected"}
        </h6>
      </Col>
    </Row>
  );
};

export function SensorData(props) {
  const { sensors, device, alerts } = props;
  return (
    <Container className="mt-2 p-0 bg-transparent device-status-div">
      <ConnectionStatus connection_type={device.connection_type} />
      {Object.keys(sensors).map((key, index) => {
        const sensor = sensors[key];
        return setSensorDataCard(index, sensor);
      })}
      Events:
      {alerts.map((alert, index) => {
        return (
          <Alert key={index} variant={alert.type}>
            {alerts.length - index}. {alert.msg}
          </Alert>
        );
      })}
    </Container>
  );
}
