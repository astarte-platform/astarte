// Copyright 2021 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import React from "react";
import { Card, ListGroup } from "react-bootstrap";
import moment from "moment";
import "moment/min/locales.min";
import _ from "lodash";

import Map from "./Map";

function getLocaleFormat() {
  const locale = window.navigator.language;
  moment.locale(locale);
  return moment.localeData().longDateFormat("LLL");
}

function renderSensorInfo(info, index) {
  return (
    <ListGroup.Item key={index} className="border-0 py-2">
      <span className="pr-2 font-weight-bold">{info.label}:</span>
      {info.value}
    </ListGroup.Item>
  );
}

function SensorLocation(props) {
  const lastLocation = _.last(props.sensorValues);
  const lastUpdate = _.get(lastLocation, "timestamp", "");
  const sensorInfos = [
    {
      label: "Sensor Name",
      value: _.get(props.sensor, "name", props.sensorId),
    },
    {
      label: "Sensor ID",
      value: props.sensorId,
    },
    {
      label: "Last Update",
      value: lastUpdate && moment(lastUpdate).format(getLocaleFormat()),
    },
  ];
  return (
    <Card className="mb-4">
      <Card.Header className="bg-white">
        <h3>{_.get(props.sensor, "name", props.sensorId)}</h3>
      </Card.Header>
      <Card.Body className="p-4">
        <ListGroup>
          {sensorInfos.map(renderSensorInfo)}
          {lastLocation && (
            <ListGroup.Item className="pt-4 border-0">
              <h3>
                {lastLocation.latitude}, {lastLocation.longitude}
              </h3>
              <Map
                latitude={lastLocation.latitude}
                longitude={lastLocation.longitude}
                popup={_.get(props.sensor, "name", props.sensorId)}
                style={{ width: "100vh", height: "300px", maxWidth: "100%" }}
              />
            </ListGroup.Item>
          )}
        </ListGroup>
      </Card.Body>
    </Card>
  );
}

export default function SensorLocationList({
  sensors,
  sensorsGeolocationData,
}) {
  return Object.keys(sensorsGeolocationData).map((sensorId) => (
    <SensorLocation
      key={sensorId}
      sensorId={sensorId}
      sensor={_.get(sensors, sensorId)}
      sensorValues={_.get(sensorsGeolocationData, sensorId)}
    />
  ));
}
