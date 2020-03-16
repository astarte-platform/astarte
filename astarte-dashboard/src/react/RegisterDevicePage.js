/*
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import React from "react";
import { v4 as uuidv4 } from "uuid";
import { Button, Col, Form, Modal, Spinner } from "react-bootstrap";

import AstarteClient from "./AstarteClient.js";
import SingleCardPage from "./ui/SingleCardPage.js";
import {
  byteArrayToUrlSafeBase64,
  urlSafeBase64ToByteArray
} from "./Base64.js";

export default class RegisterDevicePage extends React.Component {
  constructor(props) {
    super(props);

    let config = JSON.parse(localStorage.session).api_config;
    let protocol = config.secure_connection ? "https://" : "http://";
    let astarteConfig = {
      realm: config.realm,
      token: config.token,
      realmManagementUrl: protocol + config.realm_management_url,
      appengineUrl: protocol + config.appengine_url,
      pairingUrl: protocol + config.pairing_url
    };
    this.astarte = new AstarteClient(astarteConfig);

    this.updateDeviceId = this.updateDeviceId.bind(this);
    this.generateRandomUUID = this.generateRandomUUID.bind(this);
    this.setNewDeviceId = this.setNewDeviceId.bind(this);
    this.registerDevice = this.registerDevice.bind(this);
    this.handleModalCancel = this.handleModalCancel.bind(this);
    this.handleRegistrationSuccess = this.handleRegistrationSuccess.bind(this);
    this.handleRegistrationError = this.handleRegistrationError.bind(this);

    this.state = {
      showModal: false,
      deviceId: ""
    };
  }

  renderModal() {
    return (
      <Modal
        size="lg"
        show={this.state.showModal}
        onHide={this.handleModalCancel}
      >
        <Modal.Header closeButton>
          <Modal.Title>{this.state.modalTitle}</Modal.Title>
        </Modal.Header>
        <Modal.Body>{this.state.modalBody}</Modal.Body>
        <Modal.Footer>
          <Button
            variant="primary"
            onClick={this.handleModalCancel}
            style={{ width: "8em" }}
          >
            Ok
          </Button>
        </Modal.Footer>
      </Modal>
    );
  }

  render() {
    return (
      <SingleCardPage title="Register Device">
        <Form onSubmit={this.registerDevice}>
          <Form.Row>
            <Form.Group as={Col} controlId="deviceIdInput">
              <Form.Label>Device ID</Form.Label>
              <Form.Control
                type="text"
                placeholder="Your device ID"
                value={this.state.deviceId}
                onChange={this.updateDeviceId}
                autoComplete="off"
                required
                isValid={this.state.isValidDeviceId}
                isInvalid={this.state.isInvalidDeviceId}
              />
              <Form.Control.Feedback type="invalid">
                The device ID must be 22 characters long and only contain
                letters, numbers and the following characters _ -
              </Form.Control.Feedback>
            </Form.Group>
          </Form.Row>
          <Form.Row className="flex-row-reverse pr-2">
            <Button
              variant="primary"
              type="submit"
              disabled={!this.state.isValidDeviceId}
            >
              Register device
            </Button>
            <Button
              variant="secondary"
              className="mx-1"
              onClick={this.generateRandomUUID}
            >
              Generate random ID
            </Button>
          </Form.Row>
        </Form>
        {this.renderModal()}
      </SingleCardPage>
    );
  }

  registerDevice(e) {
    e.preventDefault();

    this.astarte
      .registerDevice({ deviceId: this.state.deviceId })
      .then(this.handleRegistrationSuccess)
      .catch(this.handleRegistrationError);
  }

  handleRegistrationSuccess(response) {
    let secret = response.data["credentials_secret"];

    this.setState({
      showModal: true,
      modalTitle: "Device Registered!",
      modalBody: (
        <>
          <span>The device credential secret is</span>
          <pre className="my-2">
            <code
              id="secret-code"
              className="m-1 p-2 bg-light"
              style={{ fontSize: "1.2em" }}
            >
              {secret}
            </code>
            <i
              className="fas fa-paste"
              onClick={pasteSecret}
              style={{ cursor: "copy" }}
            />
          </pre>
          <span>
            Please don't share the Credentials Secret, and ensure it is
            transferred securely to your Device.
            <br />
            Once the Device pairs for the first time, the Credentials Secret
            will be associated permanently to the Device and it won't be
            changeable anymore.
          </span>
        </>
      )
    });
  }

  handleRegistrationError(err) {
    const { name, message } = err;

    this.setState({
      showModal: true,
      modalTitle: name,
      modalBody: <p>{message}</p>
    });
  }

  setNewDeviceId(deviceId) {
    const byteArray = urlSafeBase64ToByteArray(deviceId);
    const isValid = byteArray.length == 16;

    this.setState({
      deviceId: deviceId,
      isValidDeviceId: isValid,
      isInvalidDeviceId: deviceId != "" && !isValid
    });
  }

  updateDeviceId(e) {
    this.setNewDeviceId(e.target.value);
  }

  generateRandomUUID() {
    const newUUID = uuidv4().replace(/-/g, "");
    const bytes = newUUID.match(/.{2}/g).map(b => parseInt(b, 16));
    const newDeviceID = byteArrayToUrlSafeBase64(bytes);

    this.setNewDeviceId(newDeviceID);
  }

  handleModalCancel() {
    this.setState({
      showModal: false
    });
  }
}

/* TODO use clipboard API
 * Right now the 'clipboard-write' is supported
 * only on chromium browser.
 * document.execCommand("copy") is deprecated but
 * for now it's the only reliable way to copy to clipboard
 */
function pasteSecret() {
  let secretCode = document.querySelector("#secret-code");
  let selection = window.getSelection();

  if (selection.rangeCount > 0) {
    selection.removeAllRanges();
  }

  let range = document.createRange();
  range.selectNode(secretCode);
  selection.addRange(range);
  document.execCommand("copy");
}
