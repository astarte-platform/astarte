import React, { Component } from "react";
import {
  Accordion,
  Button,
  Col,
  FormCheck,
  FormControl,
  FormGroup,
  Row,
  Spinner,
} from "react-bootstrap";
import CredentialsModal from "./CredentialsModal";
import SensorItems from "./SensorItem";

class SensorSamplingUpdate extends Component {
  constructor(props) {
    super(props);
    this.state = {
      loading: false,
      visible: false,
      current: null,
    };
  }

  componentDidMount() {
    const { sensorValues } = this.props;
    const keys = Object.keys(sensorValues);
    if (keys.length > 0) this.setState({ current: keys[0], sensor: keys[0] });
  }

  handleChange = (e) => {
    this.setState({ [e.target.name]: e.target.value });
  };
  handleSensor = (e) => {
    this.setState({
      [e.target.name]: e.target.value,
      current: e.target.value,
    });
  };
  handleCheckbox = (e) => {
    this.setState({ [e.target.name]: e.target.checked });
  };
  handleError = (err) => {
    if (err.response.status === 403) {
      this.setState({ visible: true, loading: false });
    }
  };

  handleSubmit = () => {
    this.updateSamplingRateStatus();
    this.updateSensorRateValue();
  };

  updateSensorRateValue = () => {
    const { sensor, status, samplingRate, samplingRateStatus } = this.state;
    const {
      data,
      astarte,
      samplingRateInterface,
      refreshSamplingRate,
    } = this.props;
    if (sensor && (status === "enable" || samplingRateStatus)) {
      this.setState({ loading: true });
      astarte
        .setSensorSamplingById({
          id: data.id,
          interfaces: samplingRateInterface,
          sensor_id: sensor,
          key: "samplingPeriod",
          unset: samplingRateStatus,
          params: {
            data: parseInt(samplingRate),
          },
        })
        .catch((err) => this.handleError(err))
        .then(() => {
          refreshSamplingRate(data.id, samplingRateInterface);
        })
        .catch((err) => this.handleError(err))
        .finally(() => this.setState({ loading: false }));
    }
  };

  updateSamplingRateStatus = () => {
    const { sensor, status } = this.state;
    const {
      data,
      astarte,
      samplingRateInterface,
      refreshSamplingRate,
    } = this.props;
    if (sensor && status) {
      this.setState({ loading: true });
      astarte
        .setSensorSamplingById({
          id: data.id,
          interfaces: samplingRateInterface,
          sensor_id: sensor,
          key: "enable",
          unset: status === "unset",
          params: {
            data: status === "enable",
          },
        })
        .catch((err) => this.handleError(err))
        .then(() => {
          refreshSamplingRate(data.id, samplingRateInterface);
        })
        .catch((err) => this.handleError(err))
        .finally(() => this.setState({ loading: false }));
    }
  };

  render() {
    const { sensorValues } = this.props;
    const {
      loading,
      visible,
      current,
      status,
      samplingRateStatus,
    } = this.state;
    return (
      <Col xs={12} className="border-separate">
        <div className="sensor-sampling-div">
          <Row className="main-row col-sm-9 align-items-center mx-auto my-3">
            <Col sm={3} xs={12} className={"p-0"}>
              <span>Sensor:</span>
            </Col>
            <Col sm={9} xs={12}>
              <FormGroup>
                <FormControl
                  as="select"
                  name="sensor"
                  required
                  onChange={this.handleSensor}
                  value={this.sensor}
                >
                  {Object.keys(sensorValues).map((sensorId) => {
                    return <option key={sensorId}>{sensorId}</option>;
                  })}
                </FormControl>
              </FormGroup>
            </Col>
          </Row>
          <Row className="main-row col-sm-9 align-items-center mx-auto my-3">
            <Col sm={3} xs={12} className={"p-0"}>
              <span>Sampling:</span>
            </Col>
            <Col sm={9} xs={12}>
              <FormGroup>
                <FormCheck
                  onChange={this.handleChange}
                  value="enable"
                  name="status"
                  inline
                  label="Enabled"
                  type="radio"
                />
                <FormCheck
                  onChange={this.handleChange}
                  value="disable"
                  name="status"
                  inline
                  label="Disabled"
                  type="radio"
                />
                <FormCheck
                  onChange={this.handleChange}
                  value="unset"
                  name="status"
                  inline
                  label="Auto"
                  type="radio"
                />
              </FormGroup>
            </Col>
          </Row>
          {status === "enable" ? (
            <Row className="main-row col-sm-9 mx-auto my-3">
              <Col sm={3} xs={12} className={"p-0 pt-3"}>
                <span>Period:</span>
              </Col>
              <Col sm={9} xs={12}>
                <FormGroup>
                  <FormCheck
                    onChange={this.handleCheckbox}
                    inline
                    name="samplingRateStatus"
                    label="Auto"
                    type="checkbox"
                    className="mb-3"
                  />
                  {!samplingRateStatus ? (
                    <FormControl
                      onChange={this.handleChange}
                      name="samplingRate"
                      type="number"
                      placeholder="Sampling period"
                      min={0}
                    />
                  ) : (
                    ""
                  )}
                </FormGroup>
              </Col>
            </Row>
          ) : (
            ""
          )}
          <Row className="main-row col-sm-9 mx-auto my-3  justify-content-center">
            <Col sm={6} xs={12}>
              <FormGroup>
                <Button
                  disabled={loading}
                  className="text-uppercase my-3 mx-auto"
                  type="primary"
                  onClick={this.handleSubmit}
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
                    "Update"
                  )}
                </Button>
              </FormGroup>
            </Col>
          </Row>
          <CredentialsModal
            setCredentials={this.props.setCredentials}
            visible={visible}
          />
          <Row className="main-row col-sm-9 mx-auto my-3">
            <Accordion className="col-12 pl-0">
              <SensorItems
                current={current}
                sensorValues={this.props.sensorValues}
                sensorSamplingRate={this.props.sensorSamplingRate}
              />
            </Accordion>
          </Row>
        </div>
      </Col>
    );
  }
}

export default SensorSamplingUpdate;
