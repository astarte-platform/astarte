import React, { Component } from "react";
import {
  Col,
  Container,
  FormControl,
  InputGroup,
  Row,
  Spinner,
} from "react-bootstrap";
import CredentialsModal from "./CredentialsModal";
import GraphComponent from "./GraphComponent";
import {
  constant,
  getDeviceDataByAlias,
  getDeviceDataById,
  getInterfaceByAlias,
  getInterfaceById,
  isMissingCredentials,
} from "../apiHandler";

class SensorPlotGraph extends Component {
  state = {
    visible: false,
    deviceID: null,
    data: {},
    availableSensors: {},
    sensorValues: {},
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
    if (value.length === 22) if (expression.test(value)) return constant.ID;
    return constant.ALIAS;
  };

  handleSubmit = () => {
    const { deviceID } = this.state;
    if (deviceID) {
      const type = this.checkDeviceType(deviceID);
      this.setState({
        loading: true,
        availableSensors: {},
        sensorValues: {},
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

  handleError(err) {
    if (err.response.status === 403)
      this.setState({ visible: true, loading: false });
    if (err.response.status === 404) {
      this.setState({ loading: false });
      window.confirm("Device ID Invalid");
    }
  }

  setDeviceDataById = (id, params = {}) => {
    getDeviceDataById(id, params)
      .then((res) => {
        this.setState({
          data: res.data,
          loading: false,
          fetched: true,
          ValueInterfaces: res.interfaces[res.valueIndex],
        });
        getInterfaceById(id, res.interfaces[res.availableIndex]).then(
          (response) => {
            this.setState({ availableSensors: response });
          }
        );
        getInterfaceById(id, res.interfaces[res.valueIndex]).then(
          (response) => {
            this.setState({ sensorValues: response });
          }
        );
      })
      .catch((err) => {
        this.handleError(err);
      });
  };

  setDeviceDataByAlias = (alias, params = {}) => {
    getDeviceDataByAlias(alias, params)
      .then((res) => {
        this.setState({
          data: res.data,
          loading: false,
          fetched: true,
          ValueInterfaces: res.interfaces[res.valueIndex],
        });
        getInterfaceByAlias(alias, res.interfaces[res.availableIndex]).then(
          (response) => {
            this.setState({ availableSensors: response });
          }
        );
        getInterfaceByAlias(alias, res.interfaces[res.valueIndex]).then(
          (response) => {
            this.setState({ sensorValues: response });
          }
        );
      })
      .catch((err) => {
        this.handleError(err);
      });
  };

  render() {
    const {
      visible,
      sensorValues,
      loading,
      deviceID,
      availableSensors,
      ValueInterfaces,
    } = this.state;
    return (
      <Container className="px-0 py-4" fluid>
        <Container>
          <Row>
            <Col xs={12} className="p-0">
              <h5 className="sensor-main-div text-center text-uppercase font-weight-bold text-white bg-sensor-theme mb-5 px-0 py-3">
                Sensor Plot Example
              </h5>
              <Col xs={12} className="sensor-id-search-div px-5 py-5">
                <Row className="main-row col-sm-7 align-items-center mx-auto">
                  <Col sm={2} xs={12} className={"p-0"}>
                    <span className="font-weight-normal">Device ID:</span>
                  </Col>
                  <Col sm={10} xs={12}>
                    <InputGroup>
                      <FormControl
                        placeholder="Enter Device ID Here"
                        aria-label="Enter Device ID Here"
                        aria-describedby="basic"
                        className="bg-white font-weight-normal rounded"
                        name="deviceID"
                        onChange={this.handleChange}
                      />
                      <InputGroup.Append className="ml-3">
                        <button
                          onClick={this.handleSubmit}
                          disabled={loading}
                          className="bg-sensor-theme text-white font-14 text-uppercase font-weight-normal px-4 text-decoration-none rounded"
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
                            "Submit"
                          )}
                        </button>
                      </InputGroup.Append>
                    </InputGroup>
                  </Col>
                </Row>
                <Row className="card-main-row mt-5">
                  <Col xs={12}>
                    {sensorValues &&
                      Object.keys(sensorValues).map((data, index) => (
                        <GraphComponent
                          key={index}
                          deviceID={deviceID}
                          interfaces={ValueInterfaces}
                          availableSensors={availableSensors[data]}
                          currentSensor={data}
                        />
                      ))}
                  </Col>
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

export default SensorPlotGraph;
