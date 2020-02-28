import React, {Component} from 'react';
import {Button, Col, FormControl, FormLabel, FormGroup, InputGroup, Row, Spinner} from "react-bootstrap";

class SensorPeriod extends Component {
    handleChange = e => {
        e.preventDefault();
        this.setState({[e.target.name]: e.target.value});
    };

    render() {
        console.log("Statetetet", this.state);
        const {sensorValues} = this.props;
        return (
            <div>
                <Col xs={12} className="sensor-id-search-div px-0 pt-5 pb-4">
                    <Row className="col-sm-12">
                        <Col sm={3} xs={12} className="pl-0">
                            <FormGroup>
                                <FormControl as="select" name="sensor" onChange={this.handleChange}>
                                    <option selected disabled>Select Sensor</option>
                                    {Object.keys(sensorValues).map((item, index) => {
                                        return <option key={index}>{item}</option>
                                    })}
                                </FormControl>
                            </FormGroup>
                        </Col>
                        <Col sm={3} xs={12}>
                            <FormGroup>
                                <FormControl as="select" name="enable" onChange={this.handleChange}>
                                    <option selected disabled>Select Enable/Disable</option>
                                    <option value={true}>Enable</option>
                                    <option value={false}>Disable</option>
                                </FormControl>
                            </FormGroup>
                        </Col>
                        <Col sm={3} xs={12}><FormGroup>
                            <FormControl as="input" name='samplingRate'
                                         className="bg-white font-weight-normal rounded"
                                         type={"number"} min={0}
                                         onChange={this.handleChange}
                                         placeholder={"Enter Sampling Rate"}
                            />
                        </FormGroup>
                        </Col><Col sm={1} xs={12} className="pr-0">
                        <Button
                            onClick={this.handleSubmit}
                            className="bg-sensor-theme border-success
                                                        text-uppercase font-weight-normal px-4
                                                        text-decoration-none rounded">
                            Update
                        </Button>
                    </Col>
                    </Row>
                </Col>
            </div>
        );
    }
}

export default SensorPeriod;