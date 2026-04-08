import React from "react";
import { Accordion, Button, Card, ListGroup } from "react-bootstrap";

const _ = require("lodash");

function statusToString(status) {
  if (typeof status !== "boolean") {
    return "Auto";
  } else if (status) {
    return "Enabled";
  } else {
    return "Disabled";
  }
}

function listItem(item, index) {
  return (
    <ListGroup.Item
      key={index}
      className="border-0 px-0 py-2 text-capitalize bg-transparent"
    >
      <b className="pr-2 text-dark">{item.label}:</b>
      {item.value}
    </ListGroup.Item>
  );
}

function SensorListItem(props) {
  const status = _.get(props.sampling, "enable");
  const sensor_items = [
    {
      label: "Sampling",
      value: statusToString(status),
    },
    {
      label: "Sampling Period",
      value: _.get(props.sampling, "samplingPeriod", "Auto"),
    },
  ];
  return (
    <Accordion defaultActiveKey={props.item}>
      <Card className="main-card border-0 mb-4">
        <Card.Header className="px-3 py-0 bg-white">
          <Accordion.Toggle
            className="text-dark border-0 text-uppercase w-100 text-left p-0 text-decoration-none"
            as={Button}
            variant="link"
            eventKey={props.item}
          >
            {props.item}
          </Accordion.Toggle>
        </Card.Header>
        <Accordion.Collapse className="show" eventKey={props.item}>
          <Card.Body className="p-3">
            <ListGroup className="px-4 py-3 my-2 ">
              {sensor_items.map(listItem)}
            </ListGroup>
          </Card.Body>
        </Accordion.Collapse>
      </Card>
    </Accordion>
  );
}

export default function SensorItems(props) {
  const { sensorValues, sensorSamplingRate, current } = props;
  return Object.keys(sensorValues)
    .filter((item) => item === current)
    .map((item, index) => {
      return (
        <SensorListItem
          key={index}
          item={item}
          sensorValues={sensorValues}
          sampling={sensorSamplingRate[item]}
        />
      );
    });
}
