import React, { Component } from "react";
import { Col, Form, Modal } from "react-bootstrap";

class CredentialsModal extends Component {
  constructor(props) {
    super(props);
    this.state = {
      realm: undefined,
      token: undefined,
      endpoint: undefined
    };
  }
  handleValue = e => {
    e.preventDefault();
    this.setState({ [e.target.name]: e.target.value });
  };

  handleSubmit = e => {
    const form = e.currentTarget;
    e.preventDefault();
    if (form.checkValidity() === false) {
      e.stopPropagation();
    }
    this.props.setCredentials(this.state);
  };

  componentDidUpdate(prevProps) {
    const { visible } = this.props;
    if (visible && prevProps.visible !== visible) {
      const config = localStorage.AstarteConfig;
      if (config) this.setState(JSON.parse(config));
    }
  }

  render() {
    const { visible } = this.props;
    const { realm, endpoint, token } = this.state;
    return (
      <Modal
        show={visible}
        animation={true}
        centered={true}
        dialogClassName="main-modal"
        backdrop="static"
      >
        <Modal.Body className="p-5">
          <Col xs={12}>
            <h6 className="text-center font-weight-bold mb-4">
              Enter Your Details
            </h6>
          </Col>
          <Form onSubmit={this.handleSubmit}>
            <Form.Group controlId="endPoint">
              <Form.Label className="mb-1 font-weight-bold">
                Endpoint URL
              </Form.Label>
              <Form.Control
                value={endpoint}
                required
                name="endpoint"
                onChange={this.handleValue}
                type="text"
                placeholder="Enter EndPoint"
                className="font-weight-normal rounded"
              />
            </Form.Group>
            <Form.Group controlId="realmName">
              <Form.Label className="mb-1 font-weight-bold">
                Realm Name
              </Form.Label>
              <Form.Control
                value={realm}
                required
                name="realm"
                onChange={this.handleValue}
                type="text"
                placeholder="Enter Realm Name"
                className="font-weight-normal rounded"
              />
            </Form.Group>

            <Form.Group controlId="token">
              <Form.Label className="mb-1 font-weight-bold">Token</Form.Label>
              <Form.Control
                value={token}
                required
                onChange={this.handleValue}
                name="token"
                type="text"
                placeholder="Enter Token Number"
                className="font-weight-normal rounded"
              />
            </Form.Group>
            <button
              className="mt-3 bg-sensor-theme font-14 text-white py-2 text-uppercase font-weight-normal px-4 rounded text-decoration-none"
              type="submit"
            >
              Submit
            </button>
          </Form>
        </Modal.Body>
      </Modal>
    );
  }
}

export default CredentialsModal;
