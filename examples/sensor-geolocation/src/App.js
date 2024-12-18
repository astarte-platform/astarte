// Copyright 2021 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import React, { useState } from "react";
import {
  Accordion,
  Button,
  Col,
  Container,
  FormControl,
  InputGroup,
  Row,
  Spinner,
} from "react-bootstrap";
import _ from "lodash";

import CredentialsModal from "./components/CredentialsModal";
import SensorLocationList from "./components/SensorLocationList";
import {
  getDeviceData,
  getInterface,
  isMissingCredentials,
} from "./apiHandler";

function App() {
  const [showCredentialsModal, setShowCredentialsModal] = useState(
    isMissingCredentials()
  );
  const [deviceId, setDeviceId] = useState("");
  const [device, setDevice] = useState();
  const [loading, setLoading] = useState(false);
  const [deviceSensors, setDeviceSensors] = useState({});
  const [sensorsGeolocationData, setSensorsGeolocationData] = useState({});

  const getDeviceInterfaces = (res) => {
    setDevice(res.device);
    const deviceId = res.device.id;
    if (res.availableSensorsInterface) {
      getInterface(deviceId, res.availableSensorsInterface).then(
        setDeviceSensors
      );
    } else {
      setDeviceSensors({});
    }
    if (res.geolocationInterface) {
      getInterface(deviceId, res.geolocationInterface).then(
        setSensorsGeolocationData
      );
    } else {
      setSensorsGeolocationData({});
    }
  };

  const handleError = (err) => {
    setLoading(false);
    if (err.response.status === 403) setShowCredentialsModal(true);
    if (err.response.status === 404) {
      window.confirm("Device ID Invalid");
    }
  };

  const handleSubmit = () => {
    setLoading(true);
    getDeviceData(deviceId)
      .then(getDeviceInterfaces)
      .catch(handleError)
      .finally(() => setLoading(false));
  };

  return (
    <Container className="py-4" fluid>
      <Container>
        <Row>
          <Col xs={12}>
            <h5 className="text-center font-weight-bold text-white bg-sensor-theme mb-4 py-3">
              SENSOR GEOLOCATION
            </h5>
            <Col xs={12} className="bg-gray px-5 pt-5 pb-5">
              <Row className="align-items-center">
                <Col xs={2}>
                  <span>Device ID:</span>
                </Col>
                <Col xs={10}>
                  <InputGroup>
                    <FormControl
                      placeholder="Enter Device ID"
                      name="deviceID"
                      value={deviceId}
                      onChange={(e) => setDeviceId(e.target.value)}
                    />
                    <InputGroup.Append className="ml-3">
                      <Button
                        onClick={handleSubmit}
                        disabled={loading}
                        variant="primary"
                        className="bg-sensor-theme rounded"
                      >
                        {loading ? (
                          <Spinner
                            as="span"
                            animation="border"
                            size="sm"
                            role="status"
                          />
                        ) : (
                          "SUBMIT"
                        )}
                      </Button>
                    </InputGroup.Append>
                  </InputGroup>
                </Col>
              </Row>
              <Row className="mt-5">
                <Col xs={12} className="pb-4">
                  {!_.isEmpty(device) && (
                    <h6>
                      <span
                        className={`mr-2 status-dot ${
                          device.connected ? "green" : "red"
                        }`}
                      />
                      Device {device.connected ? "Connected" : "Disconnected"}
                    </h6>
                  )}
                </Col>
                {!_.isEmpty(sensorsGeolocationData) && (
                  <Col xs={12}>
                    <Accordion>
                      <SensorLocationList
                        sensors={deviceSensors}
                        sensorsGeolocationData={sensorsGeolocationData}
                      />
                    </Accordion>
                  </Col>
                )}
              </Row>
            </Col>
          </Col>
        </Row>
      </Container>
      <CredentialsModal
        onSubmit={() => setShowCredentialsModal(false)}
        visible={showCredentialsModal}
      />
    </Container>
  );
}

export default App;
