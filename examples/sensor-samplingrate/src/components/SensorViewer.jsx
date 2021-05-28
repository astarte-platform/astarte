import React, { Component } from "react";
import {
  Button,
  Col,
  Container,
  FormControl,
  InputGroup,
  Row,
  Spinner,
} from "react-bootstrap";
import CredentialsModal from "./CredentialsModal";

import ApiHandler from "../apiHandler";
import SensorSamplingUpdate from "./SensorSamplingUpdate";

const _ = require("lodash");
const INTERFACES = {
  VALUES: "Values",
  SAMPLING_RATE: "SamplingRate",
};

class SensorViewer extends Component {
  state = {
    visible: false,
    device: null,
    data: {},
    sensorValues: {},
    sensorSamplingRate: {},
    loading: false,
    astarte: null,
    samplingRateInterface: null,
  };

  handleChange = (e) => {
    e.preventDefault();
    this.setState({ [e.target.name]: e.target.value });
  };

  componentDidMount() {
    const config = localStorage.AstarteConfig;
    if (config) {
      const astarte = new ApiHandler(JSON.parse(config));
      this.setState({ astarte, visible: false });
    } else {
      this.setState({ visible: true });
    }
  }

  handleError(err) {
    if (err.response.status === 403) {
      this.setState({ visible: true, loading: false });
      window.confirm("Invalid Credentials");
    } else if (err.response.status === 404) {
      this.setState({ loading: false });
      window.confirm("Device ID doesn't exist");
    }
  }

  handleSubmit = () => {
    const { device, astarte } = this.state;
    if (device) {
      this.setState({ loading: true });
      astarte
        .getDevice(device)
        .then((response) => this.setInterfaces(response))
        .catch((error) => this.handleError(error));
    }
  };

  setInterfaces = (res) => {
    const { astarte } = this.state;
    const id = res.id;
    const interfaces = Object.keys(res.introspection);
    const samplingRateInterface = interfaces.find(
      (key) => key.search(INTERFACES.SAMPLING_RATE) > -1
    );
    const valueInterface = interfaces.find(
      (key) => key.search(INTERFACES.VALUES) > -1
    );
    this.setState({
      data: res,
      loading: false,
      device: id,
      samplingRateInterface: samplingRateInterface,
    });
    astarte.getInterfaceById(id, valueInterface).then((response) => {
      this.setState({ sensorValues: response });
    });
    astarte.getInterfaceById(id, samplingRateInterface).then((response) => {
      this.setState({ sensorSamplingRate: response });
    });
  };

  refreshSamplingRate = (id, interfaces) => {
    const { astarte } = this.state;
    astarte.getInterfaceById(id, interfaces).then((response) => {
      this.setState({ sensorSamplingRate: response });
    });
  };

  setCredentials = (config) => {
    const astarte = new ApiHandler(config);
    localStorage.AstarteConfig = JSON.stringify(config);
    this.setState({ astarte, visible: false });
  };

  render() {
    const {
      visible,
      data,
      sensorValues,
      sensorSamplingRate,
      loading,
      samplingRateInterface,
      astarte,
    } = this.state;
    return (
      <Container className="px-0 py-4" fluid>
        <Container>
          <Row>
            <Col xs={12} className="p-0">
              <h5
                className="sensor-main-div text-center text-uppercase
                            text-white bg-sensor-theme mb-5 px-0 py-3"
              >
                <b>Sensor Configuration</b>
              </h5>
              <Col xs={12} className="sensor-id-search-div px-5 pt-5 pb-4">
                <Row className="main-row col-sm-9 align-items-center mx-auto mb-5">
                  <Col sm={3} xs={12} className={"p-0"}>
                    <label className="my-0">Device ID:</label>
                  </Col>
                  <Col sm={9} xs={12}>
                    <InputGroup>
                      <FormControl
                        placeholder="Enter ID Here"
                        aria-label="Enter ID Here"
                        aria-describedby="basic"
                        className="bg-white rounded"
                        name="device"
                        onChange={this.handleChange}
                      />
                      <InputGroup.Append className="ml-3">
                        <Button
                          onClick={this.handleSubmit}
                          disabled={loading}
                          className="bg-sensor-theme border-success
                                      text-uppercase px-4
                                       text-decoration-none rounded"
                        >
                          {loading ? (
                            <Spinner
                              as="span"
                              animation="border"
                              size="sm"
                              role="status"
                              aria-hidden="true"
                            />
                          ) : (
                            "Show"
                          )}
                        </Button>
                      </InputGroup.Append>
                    </InputGroup>
                  </Col>
                </Row>

                <Row className="card-main-row">
                  {!_.isEmpty(sensorValues) ? (
                    <SensorSamplingUpdate
                      data={data}
                      astarte={astarte}
                      sensorValues={sensorValues}
                      setCredentials={this.setCredentials}
                      samplingRateInterface={samplingRateInterface}
                      refreshSamplingRate={this.refreshSamplingRate}
                      sensorSamplingRate={sensorSamplingRate}
                    />
                  ) : (
                    ""
                  )}
                </Row>
              </Col>
            </Col>
          </Row>
        </Container>
        <CredentialsModal
          setCredentials={this.setCredentials}
          visible={visible}
        />
      </Container>
    );
  }
}

export default SensorViewer;
