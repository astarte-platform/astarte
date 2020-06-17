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
import {
  Button,
  Form,
  Modal,
  Spinner
} from "react-bootstrap";

import SingleCardPage from "./ui/SingleCardPage.js";

export default class RealmSettingsPage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.handleConfigRespose = this.handleConfigRespose.bind(this);
    this.handleConfigError = this.handleConfigError.bind(this);
    this.updateUserKey = this.updateUserKey.bind(this);
    this.showConfirmModal = this.showConfirmModal.bind(this);
    this.dismissModal = this.dismissModal.bind(this);
    this.applyNewSettings = this.applyNewSettings.bind(this);
    this.onUpdateSettingsError = this.onUpdateSettingsError.bind(this);
    this.dismissAlert = this.dismissAlert.bind(this);

    this.state = {
      alerts: new Map(),
      alertId: 0,
      phase: "loading",
      userPublicKey: "",
      showModal: false
    };

    this.astarte
      .getConfigAuth()
      .then(this.handleConfigRespose)
      .catch(this.handleConfigError);
  }

  handleConfigRespose(response) {
    const publicKey = response.data.jwt_public_key_pem;

    this.setState({
      phase: "ok",
      publicKey: publicKey,
      userPublicKey: publicKey,
    });
  }

  handleConfigError(err) {
    this.setState({
      phase: "err"
    });
  }

  updateUserKey(e) {
    const newKey = e.target.value;

    this.setState({
      userPublicKey: newKey
    });
  }

  showConfirmModal() {
    this.setState({
      showModal: true
    });
  }

  dismissModal() {
    this.setState({
      showModal: false
    });
  }

  applyNewSettings() {
    this.setState({
      isUpdating: true
    });

    this.astarte
      .updateConfigAuth(this.state.userPublicKey)
      .then(() => {this.props.history.push("/logout")})
      .catch(this.onUpdateSettingsError);
  }

  onUpdateSettingsError(err) {
    this.setState((state) => {
      const newAlertId = state.alertId + 1;
      let newAlerts = state.alerts;
      newAlerts.set(newAlertId, err.message);

      return Object.assign(state, {
        alertId: newAlertId,
        alerts: newAlerts,
        isUpdating: false,
        showModal: false
      });
    });
  }

  dismissAlert(alertId) {
    this.setState((state) => {
      state.alerts.delete(alertId);
      return state;
    });
  }

  render() {
    let innerHTML;

    const {
      alerts,
      isUpdating,
      phase,
      publicKey,
      showModal,
      userPublicKey
    } = this.state;

    switch (phase) {
      case "ok":
        innerHTML = (
          <Form>
            <Form.Group controlId="public-key">
              <Form.Label>Public key</Form.Label>
              <Form.Control
                as="textarea"
                className="text-monospace"
                rows="16"
                value={userPublicKey}
                onChange={this.updateUserKey}
              />
            </Form.Group>
            {/* TODO: this action is destructive, maybe we should use danger/warning variants */}
            <Button
              variant="primary"
              disabled={userPublicKey == publicKey}
              onClick={this.showConfirmModal}
            >
              Apply
            </Button>
          </Form>
        );
        break;

      case "err":
        innerHTML = <p>Couldn't load realm settings</p>;
        break;

      default:
        innerHTML = (
          <div>
            <Spinner animation="border" role="status" />
          </div>
        );
        break;
    }

    return (
      <SingleCardPage title="Realm Settings"
        errorMessages={alerts}
        onAlertClose={this.dismissAlert}
      >
        {innerHTML}
        <ConfirmKeyChanges
          isUpdating={isUpdating}
          show={showModal}
          onCancel={this.dismissModal}
          onConfirm={this.applyNewSettings}
        />
      </SingleCardPage>
    );
  }
}

function ConfirmKeyChanges({ show, isUpdating, onCancel, onConfirm }) {
  return (
    <div onKeyDown={(e) => { if (e.key == "Enter") onConfirm() }}>
      <Modal
        size="lg"
        show={show}
        onHide={onCancel}
      >
        <Modal.Header closeButton>
          <Modal.Title>Confirm Public Key Update</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <p>Realm public key will be changed, users will not be able to make further API calls using their current auth token. Confirm?</p>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={onCancel}>
            Cancel
          </Button>
          <Button variant="primary" onClick={onConfirm}>
            {isUpdating && (
              <Spinner
                className="mr-1"
                size="sm"
                animation="border"
                role="status"
              />
            )}
            Update settings
          </Button>
        </Modal.Footer>
      </Modal>
    </div>
  );
}
