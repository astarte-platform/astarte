// Copyright 2020-2021 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import React, { Component } from "react";
import { Button, Col, Form, Modal } from "react-bootstrap";
import {
  getAuthToken,
  getEndPoint,
  getRealmName,
  setAuthToken,
  setEndPoint,
  setRealmName,
} from "../apiHandler";

class CredentialsModal extends Component {
  state = {
    realm_name: undefined,
    token: undefined,
    endpoint: undefined,
  };

  handleValue = (e) => {
    e.preventDefault();
    this.setState({ [e.target.name]: e.target.value });
  };

  handleSubmit = (e) => {
    const form = e.currentTarget;
    e.preventDefault();
    if (form.checkValidity() === false) {
      e.stopPropagation();
    }
    const { token, realm_name, endpoint } = this.state;
    setAuthToken(token);
    setRealmName(realm_name);
    setEndPoint(new window.URL(endpoint).href);
    this.props.handleCredentialModal();
  };

  componentDidUpdate(prevProps) {
    const { visible } = this.props;
    if (visible && prevProps.visible !== visible) {
      this.setState({
        realm_name: getRealmName(),
        token: getAuthToken(),
        endpoint: getEndPoint(),
      });
    }
  }

  render() {
    const { visible } = this.props;
    const { realm_name, endpoint, token } = this.state;
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
                value={realm_name}
                required
                name="realm_name"
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
            <Button
              className="mt-3 bg-sensor-theme border-success text-uppercase font-weight-normal px-4 rounded text-decoration-none"
              variant="primary"
              type="submit"
            >
              Submit
            </Button>
          </Form>
        </Modal.Body>
      </Modal>
    );
  }
}

export default CredentialsModal;
