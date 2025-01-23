// Copyright 2020-2021 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import { Accordion, Button, Card, ListGroup } from "react-bootstrap";
import { Images } from "../Images";
import React from "react";

const _ = require("lodash");
const moment = require("moment");
require("moment/min/locales.min");

function getLocaleFormat() {
  const locale = window.navigator.language;
  moment.locale(locale);
  return moment.localeData().longDateFormat("LLL");
}

function listItem(item, index) {
  return (
    <ListGroup.Item
      key={index}
      className="border-0 px-0 py-2 font-weight-normal text-capitalize bg-transparent"
    >
      <span className="pr-2 text-dark font-weight-bold">{item.label}:</span>
      {item.value}
    </ListGroup.Item>
  );
}

function SensorListItem(props) {
  const sensor_items = [
    {
      label: "Sensor Name",
      value: _.get(props.sensor, "name", props.sensorId),
    },
    {
      label: "Sensor ID",
      value: props.sensorId,
    },
    {
      label: "Sampling Period",
      value: _.get(props.sampling, "samplingPeriod", "N/A"),
    },
    {
      label: "Last Update",
      value: moment(props.sensorValues.value.timestamp).format(
        getLocaleFormat()
      ),
    },
  ];
  return (
    <Card className="main-card border-0 mb-4">
      <Card.Header className="px-3 py-0 bg-white">
        <Accordion.Toggle
          className="text-dark border-0 font-weight-bold text-uppercase w-100 text-left p-0 text-decoration-none"
          as={Button}
          variant="link"
          eventKey={props.sensorId}
        >
          {_.get(props.sensor, "name", props.sensorId)}
          <img src={Images.down_arrow} alt={"down-arrow"} />
        </Accordion.Toggle>
      </Card.Header>
      <Accordion.Collapse eventKey={props.sensorId}>
        <Card.Body className="p-3">
          <ListGroup className="px-4 py-3 my-2 ">
            {sensor_items.map(listItem)}
            <ListGroup.Item className="temperature-list pt-4 border-0 pb-0 py-2 font-weight-normal bg-transparent text-uppercase">
              <h1>
                {props.sensorValues.value.value}
                <span className="text-dark">
                  {" "}
                  {_.get(props.sensor, "unit", "")}
                </span>
              </h1>
            </ListGroup.Item>
          </ListGroup>
        </Card.Body>
      </Accordion.Collapse>
    </Card>
  );
}

export default function SensorItems({
  availableSensors,
  sensorsValues,
  sensorSamplingRate,
}) {
  return Object.keys(sensorsValues).map((sensorId, index) => {
    return (
      <SensorListItem
        key={index}
        sensorId={sensorId}
        sensorValues={_.get(sensorsValues, sensorId)}
        sensor={_.get(availableSensors, sensorId)}
        sampling={_.get(sensorSamplingRate, sensorId)}
      />
    );
  });
}
