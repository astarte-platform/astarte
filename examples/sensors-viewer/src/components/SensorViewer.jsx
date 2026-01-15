import React, { Component } from "react";
import { Accordion, Button, Col, Container, FormControl, InputGroup, Row, Spinner } from "react-bootstrap";
import {
  constant,
  getDeviceDataByAlias,
  getDeviceDataById,
  getInterfaceById,
  isMissingCredentials,
} from "../apiHandler";
import CredentialsModal from "./CredentialsModal";
import SensorItem from "./SensorItem";

const _ = require("lodash");

class SensorViewer extends Component {
  state = {
    visible: false,
    deviceID: null,
    data: {},
    availableSensors: {},
    sensorsValues: {},
    sensorsSamplingRate: {},
    loading: false,
    fetched: false,
  };

  componentDidMount() {
    if (isMissingCredentials()) this.setState({ visible: true });
  }

  handleChange = (e) => {
    e.preventDefault();
    this.setState({ [e.target.name]: e.target.value });
  };

  handleCredentialModal = (visible) => {
    this.setState({ visible });
    if (!visible) {
      this.handleSubmit();
    }
  };

  checkDeviceType = (value) => {
    const expression = new RegExp(/[a-z]?[A-Z]?[0-9]?-?_?/i);
    if (value.length === 22) { if (expression.test(value)) return constant.ID; }
    return constant.ALIAS;
  };

  handleError(err) {
    if (err.response.status === 403) {
      this.setState({ visible: true, loading: false });
    }
    if (err.response.status === 404) {
      this.setState({ loading: false });
      window.confirm("Device ID Invalid");
    }
  }

  handleSubmit = () => {
    const { deviceID } = this.state;
    if (deviceID) {
      const type = this.checkDeviceType(deviceID);
      this.setState({
        loading: true,
        availableSensors: {},
        sensorsValues: {},
        sensorsSamplingRate: {},
        fetched: false,
        notFound: false,
      });
      if (type === constant.ID) {
        this.setDeviceDataById(deviceID);
      } else {
        this.setDeviceDataByAlias(deviceID);
      }
    }
  };

  setInterfaces = (res) => {
    const id = res.data.id;
    this.setState({
      data: res.data,
      loading: false,
      fetched: true,
    });
    if (res.availableSensorsInterface) {
      getInterfaceById(id, res.availableSensorsInterface).then((response) => {
        this.setState({ availableSensors: response });
      });
    }
    if (res.valuesInterface) {
      getInterfaceById(id, res.valuesInterface).then((response) => {
        this.setState({ sensorsValues: response });
      });
    }
    if (res.samplingRateInterface) {
      getInterfaceById(id, res.samplingRateInterface).then((response) => {
        this.setState({ sensorsSamplingRate: response });
      });
    }
  };

  setDeviceDataById = (id, params = {}) => {
    getDeviceDataById(id, params)
      .then((res) => this.setInterfaces(res))
      .catch((err) => this.handleError(err));
  };

  setDeviceDataByAlias = (alias, params = {}) => {
    getDeviceDataByAlias(alias, params)
      .then((res) => this.setInterfaces(res))
      .catch((err) => this.handleError(err));
  };

  render() {
    const {
      visible,
      data,
      availableSensors,
      sensorsValues,
      sensorsSamplingRate,
      loading,
      fetched,
    } = this.state;
    return (
      <Container className="px-0 py-4" fluid>
        <Container>
          <Row>
            <Col xs={12} className="p-0">
              <h5 className="sensor-main-div text-center text-uppercase
                                font-weight-bold text-white bg-sensor-theme mb-5 px-0 py-3">
                Sensors Viewer
              </h5>
              <Col xs={12} className="sensor-id-search-div px-5 pt-5 pb-4">
                <Row className="main-row col-sm-7 align-items-center mx-auto">
                  <Col sm={2} xs={12} className={"p-0"}>
                    <span className="font-weight-normal">Device ID:</span>
                  </Col>
                  <Col sm={10} xs={12}>
                    <InputGroup>
                      <FormControl
                        placeholder="Enter ID Here"
                        aria-label="Enter ID Here"
                        aria-describedby="basic"
                        className="bg-white font-weight-normal rounded"
                        name="deviceID"
                        onChange={this.handleChange}
                      />
                      <InputGroup.Append className="ml-3">
                        <Button
                          onClick={this.handleSubmit}
                          disabled={loading}
                          className="bg-sensor-theme border-success
                                                        text-uppercase font-weight-normal px-4
                                                        text-decoration-none rounded"
                        >
                          {loading
                            ? (
                              <Spinner
                                as="span"
                                animation="border"
                                size="sm"
                                role="status"
                                aria-hidden="true"
                              />
                            )
                            : (
                              "Submit"
                            )}
                        </Button>
                      </InputGroup.Append>
                    </InputGroup>
                  </Col>
                </Row>
                <Row className="card-main-row mt-5">
                  <Col xs={12} className="device-status-div px-3 pb-4">
                    {fetched
                      ? (
                        <h6 className="m-0 font-weight-bold position-relative">
                          <span
                            className="status-tag rounded-circle d-inline-block mr-2"
                            style={{
                              backgroundColor: `${data.connected ? "#008000" : "#ff0000"}`,
                            }}
                          />
                          Device {data.connected ? "Connected" : "Disconnected"}
                        </h6>
                      )
                      : (
                        ""
                      )}
                  </Col>
                  {!_.isEmpty(sensorsValues)
                    ? (
                      <Col xs={12}>
                        <Accordion>
                          <SensorItem
                            availableSensors={availableSensors}
                            sensorsValues={sensorsValues}
                            sensorsSamplingRate={sensorsSamplingRate}
                          />
                        </Accordion>
                      </Col>
                    )
                    : (
                      ""
                    )}
                </Row>
              </Col>
            </Col>
          </Row>
        </Container>
        <CredentialsModal
          handleCredentialModal={() => this.handleCredentialModal(false)}
          visible={visible}
        />
      </Container>
    );
  }
}

export default SensorViewer;
