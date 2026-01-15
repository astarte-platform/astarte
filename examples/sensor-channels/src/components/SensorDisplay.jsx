import React, { Component } from "react";
import { Button, Col, Container, FormControl, InputGroup, Row, Spinner } from "react-bootstrap";
import ApiHandler from "../apiHandler";
import CredentialsModal from "./CredentialsModal";
import SensorDataHandler from "./SensorDataHandler";

class SensorDisplay extends Component {
  constructor(props) {
    super(props);
    this.state = {
      visible: false,
      device: null,
      astarte: null,
      loading: false,
      submit: false,
    };
  }

  componentDidMount() {
    const config = localStorage.AstarteConfig;
    if (config) {
      const astarte = new ApiHandler(JSON.parse(config));
      this.setState({ astarte, visible: false });
    } else {
      this.setState({ visible: true });
    }
  }

  setCredentials = (config) => {
    const astarte = new ApiHandler(config);
    localStorage.AstarteConfig = JSON.stringify(config);
    this.setState({ astarte, visible: false }, () => this.handleSubmit());
  };

  handleChange = (e) => {
    e.preventDefault();
    this.setState({ [e.target.name]: e.target.value, submit: false });
  };

  handleCredentialModal = (visible) => {
    this.setState({ visible });
    if (!visible) {
      this.handleSubmit();
    }
  };

  handleSubmit = () => {
    const { device, astarte } = this.state;
    if (device) {
      this.setState({ loading: true });
      astarte
        .getDevice(device)
        .then((response) => this.setDeviceData(response))
        .catch((error) => this.handleError(error));
    }
  };

  setDeviceData(response) {
    this.setState({
      device: response.id,
      loading: false,
      submit: true,
    });
  }

  handleError(err) {
    if (err.response.status === 403) {
      this.setState({ visible: true, loading: false });
      window.confirm("Invalid Credentials");
    }
    if (err.response.status === 404) {
      this.setState({ loading: false });
      window.confirm("Device ID doesn't exist");
    }
  }

  render() {
    const { visible, loading, device, submit, astarte } = this.state;
    return (
      <Container className="px-0 py-4" fluid>
        <Container>
          <Row>
            <Col xs={12} className="p-0">
              <h5 className="text-center text-uppercase font-weight-bold text-white bg-sensor-theme mb-5 py-3">
                Sensor Real-Time Data
              </h5>
              <Col xs={12} className="sensor-id-search-div p-5">
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
                        name="device"
                        onChange={this.handleChange}
                      />
                      <InputGroup.Append className="ml-3">
                        <Button
                          onClick={this.handleSubmit}
                          disabled={loading}
                          className="bg-sensor-theme text-uppercase font-weight-normal px-4 text-decoration-none rounded"
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
                              "Show"
                            )}
                        </Button>
                      </InputGroup.Append>
                    </InputGroup>
                  </Col>
                </Row>
              </Col>
            </Col>
          </Row>
          <Row>
            {submit ? <SensorDataHandler astarte={astarte} device={device} /> : (
              ""
            )}
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

export default SensorDisplay;
