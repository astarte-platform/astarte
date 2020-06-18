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
import { v4 as uuidv4, v5 as uuidv5 } from "uuid";
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

    this.astarte = this.props.astarte;

    this.updateDeviceId = this.updateDeviceId.bind(this);
    this.generateRandomUUID = this.generateRandomUUID.bind(this);
    this.setNewDeviceId = this.setNewDeviceId.bind(this);
    this.registerDevice = this.registerDevice.bind(this);
    this.handleRegistrationSuccess = this.handleRegistrationSuccess.bind(this);
    this.handleRegistrationError = this.handleRegistrationError.bind(this);
    this.credentialModalCancel = this.credentialModalCancel.bind(this);
    this.namespaceModalCancel = this.namespaceModalCancel.bind(this);
    this.showNamespaceModal = this.showNamespaceModal.bind(this);
    this.onNamespaceChange = this.onNamespaceChange.bind(this);
    this.onCustromStringChange = this.onCustromStringChange.bind(this);
    this.maybeGenerateDeviceId = this.maybeGenerateDeviceId.bind(this);
    this.confirmNamespacedId = this.confirmNamespacedId.bind(this);
    this.returnToDeviceListPage = this.returnToDeviceListPage.bind(this);

    this.state = {
      showCredentialSecretModal: false,
      showNamespaceModal: false,
      deviceId: "",
      namespace: "",
      customString: "",
      namespacedID: ""
    };
  }

  renderCredentialSecretModal() {
    const { showCredentialSecretModal } = this.state;

    return (
      <Modal
        size="lg"
        show={showCredentialSecretModal}
        onHide={this.credentialModalCancel}
      >
        <Modal.Header closeButton>
          <Modal.Title>{this.state.modalTitle}</Modal.Title>
        </Modal.Header>
        <Modal.Body>{this.state.modalBody}</Modal.Body>
        <Modal.Footer>
          <Button
            variant="primary"
            onClick={this.returnToDeviceListPage}
            style={{ width: "8em" }}
          >
            Ok
          </Button>
        </Modal.Footer>
      </Modal>
    );
  }

  renderNamespaceModal() {
    const { showNamespaceModal, namespace, customString } = this.state;

    return (
      <Modal
        size="lg"
        show={showNamespaceModal}
        onHide={this.namespaceModalCancel}
      >
        <Modal.Header closeButton>
          <Modal.Title>Generate from name</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <Form>
            <Form.Group controlId="userNamespace">
              <Form.Label>Namespace UUID in canonical text format</Form.Label>
              <Form.Control
                type="text"
                placeholder="e.g.: 753ffc99-dd9d-4a08-a07e-9b0d6ce0bc82"
                value={namespace}
                onChange={this.onNamespaceChange}
                isValid={namespace !== "" && this.state.namespacedID !== ""}
                isInvalid={namespace !== "" && this.state.namespacedID === ""}
                required
              />
              <Form.Control.Feedback type="invalid">
                The namespace must be a valid UUID
              </Form.Control.Feedback>
            </Form.Group>
            <Form.Group controlId="userString">
              <Form.Label>Name</Form.Label>
              <Form.Control
                type="text"
                placeholder="e.g.: my device"
                value={customString}
                onChange={this.onCustromStringChange}
              />
            </Form.Group>
          </Form>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={this.namespaceModalCancel}>
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={this.confirmNamespacedId}
            disabled={this.state.namespacedID === ""}
          >
            Generate ID
          </Button>
        </Modal.Footer>
      </Modal>
    );
  }

  render() {
    return (
      <SingleCardPage title="Register Device" backLink="/devices">
        <Form onSubmit={this.registerDevice}>
          <Form.Row>
            <Form.Group as={Col} controlId="deviceIdInput">
              <Form.Label>Device ID</Form.Label>
              <Form.Control
                type="text"
                className="text-monospace"
                placeholder="Your device ID"
                value={this.state.deviceId}
                onChange={this.updateDeviceId}
                autoComplete="off"
                required
                isValid={this.state.isValidDeviceId}
                isInvalid={this.state.isInvalidDeviceId}
              />
              <Form.Control.Feedback type="invalid">
                Device ID must be a unique 128 bit URL-encoded base64 (without padding) string.
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
              onClick={this.showNamespaceModal}
            >
              Generate from name...
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
        {this.renderCredentialSecretModal()}
        {this.renderNamespaceModal()}
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
      showCredentialSecretModal: true,
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
      showCredentialSecretModal: true,
      modalTitle: name,
      modalBody: <p>{message}</p>
    });
  }

  setNewDeviceId(deviceId) {
    const byteArray = urlSafeBase64ToByteArray(deviceId);
    const isValid = byteArray.length == 17 && byteArray[16] === 0;

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

  credentialModalCancel() {
    this.setState({
      showCredentialSecretModal: false
    });
  }

  returnToDeviceListPage() {
    this.props.history.push({ pathname: "/devices" });
  }

  onNamespaceChange(e) {
    const namespace = e.target.value;

    this.setState({
      namespace: namespace
    });
    this.maybeGenerateDeviceId(namespace, this.state.customString);
  }

  onCustromStringChange(e) {
    const customString = e.target.value;

    this.setState({
      customString: customString
    });
    this.maybeGenerateDeviceId(this.state.namespace, customString);
  }

  showNamespaceModal() {
    this.setState({
      showNamespaceModal: true
    });
  }

  namespaceModalCancel() {
    this.setState({
      showNamespaceModal: false
    });
  }

  maybeGenerateDeviceId(namespace, customString) {
    let newDeviceID;

    try {
      const newUUID = uuidv5(customString, namespace).replace(/-/g, "");
      const bytes = newUUID.match(/.{2}/g).map(b => parseInt(b, 16));
      newDeviceID = byteArrayToUrlSafeBase64(bytes);
    } catch (e) {
      // namespace is not a UUID
      newDeviceID = "";
    }

    this.setState({
      namespacedID: newDeviceID
    });
  }

  confirmNamespacedId() {
    const { namespacedID } = this.state;
    this.setNewDeviceId(namespacedID);

    this.setState({
      showNamespaceModal: false
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
