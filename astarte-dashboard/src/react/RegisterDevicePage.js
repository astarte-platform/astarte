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

import React, { useState } from "react";
import { v4 as uuidv4, v5 as uuidv5 } from "uuid";
import { Button, Col, Form, Modal, Spinner, Table } from "react-bootstrap";

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
    this.toggleIntrospection = this.toggleIntrospection.bind(this);
    this.addInterfaceToIntrospection = this.addInterfaceToIntrospection.bind(this);
    this.removeIntrospectionInterface = this.removeIntrospectionInterface.bind(this);

    this.state = {
      showCredentialSecretModal: false,
      showNamespaceModal: false,
      sendIntrospection: false,
      introspectionInterfaces: new Map(),
      deviceId: "",
      namespace: "",
      customString: "",
      namespacedID: "",
      isRegisteringDevice: false
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
    const {
      deviceId,
      isValidDeviceId,
      isInvalidDeviceId,
      sendIntrospection,
      introspectionInterfaces,
      isRegisteringDevice
    } = this.state;

    return (
      <SingleCardPage title="Register Device" backLink="/devices">
        <Form onSubmit={this.registerDevice}>
          <Form.Row className="mb-2">
            <Form.Group as={Col} controlId="deviceIdInput">
              <Form.Label>Device ID</Form.Label>
              <Form.Control
                type="text"
                className="text-monospace"
                placeholder="Your device ID"
                value={deviceId}
                onChange={this.updateDeviceId}
                autoComplete="off"
                required
                isValid={isValidDeviceId}
                isInvalid={isInvalidDeviceId}
              />
              <Form.Control.Feedback type="invalid">
                Device ID must be a unique 128 bit URL-encoded base64 (without padding) string.
              </Form.Control.Feedback>
            </Form.Group>
            <Form.Group as={ColNoLabel}>
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
            </Form.Group>
          </Form.Row>
          <Form.Group controlId="sendIntrospectionInput" className={sendIntrospection && "mb-0"}>
            <Form.Check
              type="checkbox"
              label="Declare initial introspection"
              checked={sendIntrospection}
              onChange={this.toggleIntrospection}
            />
          </Form.Group>
          { sendIntrospection &&
            <InstrospectionTable
              interfaces={introspectionInterfaces}
              onAddInterface={this.addInterfaceToIntrospection}
              onRemoveInterface={this.removeIntrospectionInterface}
            />
          }
          <Form.Row className="flex-row-reverse pr-2">
            <Button
              variant="primary"
              type="submit"
              disabled={!isValidDeviceId || isRegisteringDevice}
            >
              {isRegisteringDevice && (
                <Spinner
                  as="span"
                  size="sm"
                  animation="border"
                  role="status"
                  className={"mr-2"}
                />
              )}
              Register device
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
    this.setState({ isRegisteringDevice: true });

    const params = {
      deviceId: this.state.deviceId
    };

    if (this.state.sendIntrospection) {
      params.introspection = this.state.introspectionInterfaces
    }

    this.astarte
      .registerDevice(params)
      .then(this.handleRegistrationSuccess)
      .catch(this.handleRegistrationError)
      .finally(() => this.setState({ isRegisteringDevice: false }));
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

  toggleIntrospection(e) {
    const sendIntrospection = e.target.checked;

    this.setState({
      sendIntrospection: sendIntrospection
    });
  }

  addInterfaceToIntrospection(interfaceId) {
    this.setState((state, props) => ({
      introspectionInterfaces: state.introspectionInterfaces.set(interfaceId.name, interfaceId)
    }));
  }

  removeIntrospectionInterface(interfaceId) {
    this.setState((state, props) => {
      let introspection = state.introspectionInterfaces;
      introspection.delete(interfaceId.name);

      return {
        introspectionInterfaces: introspection
      }
    });
  }
}

function InstrospectionTable({interfaces, onAddInterface, onRemoveInterface}) {
  return (
    <Table className="mb-4" responsive>
      <thead>
        <tr>
          <th>Interface name</th>
          <th>Major</th>
          <th>Minor</th>
          <th className="action-column"></th>
        </tr>
      </thead>
      <tbody>
        { Array.from(interfaces).map(([key, interfaceId]) =>
          <InterfaceIntrospectionRow
            key={key}
            name={interfaceId.name}
            major={interfaceId.major}
            minor={interfaceId.minor}
            onRemove={() => onRemoveInterface(interfaceId)}
          />
        )}
        <IntrospectionControlRow
          onAddInterface={onAddInterface}
        />
      </tbody>
    </Table>
  );
}

function InterfaceIntrospectionRow({name, major, minor, onRemove}) {
  return (
    <tr>
      <td>{name}</td>
      <td>{major}</td>
      <td>{minor}</td>
      <td>
        <i className="fas fa-eraser color-red action-icon" onClick={onRemove} />
      </td>
    </tr>
  );
}

function IntrospectionControlRow({onAddInterface}) {
  const initialState = {
    name: "",
    major: 0,
    minor: 1
  };

  const [interfaceId, setInterfaceId] = useState(initialState);

  const handleNameChange = ({ target: {value} }) =>
    setInterfaceId((state) => ({ ...state, name: value }))

  const handleMajorChange = ({ target: {value} }) =>
    setInterfaceId((state) => ({ ...state, major: parseInt(value) || 0 }))

  const handleMinorChange = ({ target: {value} }) =>
    setInterfaceId((state) => ({ ...state, minor: parseInt(value) || 0 }))

  return (
    <tr>
      <td>
        <Form.Control
          type="text"
          placeholder="Interface name"
          value={interfaceId.name}
          onChange={handleNameChange}
        />
      </td>
      <td>
        <Form.Control
          type="number"
          min="0"
          value={interfaceId.major}
          onChange={handleMajorChange}
        />
      </td>
      <td>
        <Form.Control
          type="number"
          min="0"
          value={interfaceId.minor}
          onChange={handleMinorChange}
        />
      </td>
      <td>
        <Button
          variant="secondary"
          disabled={interfaceId.name == ""}
          onClick={() => {
            onAddInterface(interfaceId);
            setInterfaceId(initialState);
          }}
        >
          Add
        </Button>
      </td>
    </tr>
  );
}

function ColNoLabel({ sm, className, ...otherProps }) {
  return (
    <Col sm="auto" className={"col-no-label ".concat(className)} {...otherProps} />
  );
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
