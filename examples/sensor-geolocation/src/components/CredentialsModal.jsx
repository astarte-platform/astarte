import React, { useState } from "react";
import { Button, Col, Form, Modal } from "react-bootstrap";
import {
  getAuthToken,
  getEndpoint,
  getRealmName,
  setAuthToken,
  setEndpoint,
  setRealmName,
} from "../apiHandler";

const CredentialsModal = (props) => {
  const [credentials, setCredentials] = useState({
    endpoint: getEndpoint(),
    realmName: getRealmName(),
    token: getAuthToken(),
  });

  const handleSubmit = (e) => {
    const form = e.currentTarget;
    e.preventDefault();
    if (form.checkValidity() === false) {
      e.stopPropagation();
    }
    setAuthToken(credentials.token);
    setRealmName(credentials.realmName);
    setEndpoint(new window.URL(credentials.endpoint).href);
    props.onSubmit();
  };

  return (
    <Modal
      show={props.visible}
      animation={true}
      centered={true}
      backdrop="static"
    >
      <Modal.Body className="p-4">
        <Col xs={12}>
          <h5 className="text-center font-weight-bold mb-4">
            Credentials Needed
          </h5>
        </Col>
        <Form onSubmit={handleSubmit}>
          <Form.Group controlId="endpoint">
            <Form.Label className="mb-2 font-weight-bold">
              Endpoint URL
            </Form.Label>
            <Form.Control
              value={credentials.endpoint}
              required
              name="endpoint"
              onChange={(e) =>
                setCredentials({ ...credentials, endpoint: e.target.value })
              }
              type="text"
              placeholder="Enter Astarte endpoint"
            />
          </Form.Group>
          <Form.Group controlId="realmName">
            <Form.Label className="mb-2 font-weight-bold">
              Realm name
            </Form.Label>
            <Form.Control
              value={credentials.realmName}
              required
              name="realmName"
              onChange={(e) =>
                setCredentials({ ...credentials, realmName: e.target.value })
              }
              type="text"
              placeholder="Enter Realm name"
            />
          </Form.Group>
          <Form.Group controlId="token">
            <Form.Label className="mb-2 font-weight-bold">Token</Form.Label>
            <Form.Control
              value={credentials.token}
              required
              onChange={(e) =>
                setCredentials({ ...credentials, token: e.target.value })
              }
              name="token"
              type="text"
              placeholder="Enter JWT token with AppEngine claims"
            />
          </Form.Group>
          <Button
            className="mt-3 bg-sensor-theme"
            variant="primary"
            type="submit"
          >
            SUBMIT
          </Button>
        </Form>
      </Modal.Body>
    </Modal>
  );
};

export default CredentialsModal;
