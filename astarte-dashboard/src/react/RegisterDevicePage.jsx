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

/* @global document */

import React, { useCallback, useMemo, useState } from 'react';
import { v4 as uuidv4, v5 as uuidv5 } from 'uuid';
import { Button, Col, Form, Modal, Spinner, Table } from 'react-bootstrap';

import SingleCardPage from './ui/SingleCardPage';
import { byteArrayToUrlSafeBase64, urlSafeBase64ToByteArray } from './Base64';
import { useAlerts } from './AlertManager';

/* TODO use clipboard API
 * Right now the 'clipboard-write' is supported
 * only on chromium browser.
 * document.execCommand("copy") is deprecated but
 * for now it's the only reliable way to copy to clipboard
 */
function pasteSecret() {
  const secretCode = document.querySelector('#secret-code');
  const selection = window.getSelection();

  if (selection.rangeCount > 0) {
    selection.removeAllRanges();
  }

  const range = document.createRange();
  range.selectNode(secretCode);
  selection.addRange(range);
  document.execCommand('copy');
}

const ColNoLabel = ({ sm, className, ...otherProps }) => (
  <Col sm="auto" className={'col-no-label '.concat(className)} {...otherProps} />
);

const InstrospectionTable = ({ interfaces, onAddInterface, onRemoveInterface }) => (
  <Table className="mb-4" responsive>
    <thead>
      <tr>
        <th>Interface name</th>
        <th>Major</th>
        <th>Minor</th>
        <th className="action-column"> </th>
      </tr>
    </thead>
    <tbody>
      {Array.from(interfaces).map(([key, interfaceDescriptor]) => (
        <InterfaceIntrospectionRow
          key={key}
          name={interfaceDescriptor.name}
          major={interfaceDescriptor.major}
          minor={interfaceDescriptor.minor}
          onRemove={() => onRemoveInterface(interfaceDescriptor)}
        />
      ))}
      <IntrospectionControlRow onAddInterface={onAddInterface} />
    </tbody>
  </Table>
);

const InterfaceIntrospectionRow = ({ name, major, minor, onRemove }) => (
  <tr>
    <td>{name}</td>
    <td>{major}</td>
    <td>{minor}</td>
    <td>
      <i className="fas fa-eraser color-red action-icon" onClick={onRemove} />
    </td>
  </tr>
);

const IntrospectionControlRow = ({ onAddInterface }) => {
  const initialState = {
    name: '',
    major: 0,
    minor: 1,
  };

  const [interfaceDescriptor, setInterfaceDescriptor] = useState(initialState);

  const handleNameChange = ({ target: { value } }) => {
    setInterfaceDescriptor((state) => ({ ...state, name: value }));
  };

  const handleMajorChange = ({ target: { value } }) => {
    setInterfaceDescriptor((state) => ({
      ...state,
      major: parseInt(value, 10) || 0,
    }));
  };

  const handleMinorChange = ({ target: { value } }) => {
    setInterfaceDescriptor((state) => ({
      ...state,
      minor: parseInt(value, 10) || 0,
    }));
  };

  return (
    <tr>
      <td>
        <Form.Control
          type="text"
          placeholder="Interface name"
          value={interfaceDescriptor.name}
          onChange={handleNameChange}
        />
      </td>
      <td>
        <Form.Control
          type="number"
          min="0"
          value={interfaceDescriptor.major}
          onChange={handleMajorChange}
        />
      </td>
      <td>
        <Form.Control
          type="number"
          min="0"
          value={interfaceDescriptor.minor}
          onChange={handleMinorChange}
        />
      </td>
      <td>
        <Button
          variant="secondary"
          disabled={interfaceDescriptor.name === ''}
          onClick={() => {
            onAddInterface(interfaceDescriptor);
            setInterfaceDescriptor(initialState);
          }}
        >
          Add
        </Button>
      </td>
    </tr>
  );
};

const CredentialSecretModal = ({ show, secret, onConfirm }) => (
  <Modal size="lg" show={show} onHide={onConfirm}>
    <Modal.Header closeButton>
      <Modal.Title>Device Registered!</Modal.Title>
    </Modal.Header>
    <Modal.Body>
      <span>The device credential secret is</span>
      <pre className="my-2">
        <code id="secret-code" className="m-1 p-2 bg-light" style={{ fontSize: '1.2em' }}>
          {secret}
        </code>
        <i className="fas fa-paste" onClick={pasteSecret} style={{ cursor: 'copy' }} />
      </pre>
      <span>
        Please don&apos;t share the Credentials Secret, and ensure it is transferred securely to
        your Device.
        <br />
        Once the Device pairs for the first time, the Credentials Secret will be associated
        permanently to the Device and it won&apos;t be changeable anymore.
      </span>
    </Modal.Body>
    <Modal.Footer>
      <Button variant="primary" onClick={onConfirm} style={{ width: '8em' }}>
        Ok
      </Button>
    </Modal.Footer>
  </Modal>
);

const NamespaceModal = ({ show, onCancel, onConfirm }) => {
  const [namespace, setNamespace] = useState('');
  const [customString, setCustomString] = useState('');

  const newDeviceId = useMemo(() => {
    try {
      const newUUID = uuidv5(customString, namespace).replace(/-/g, '');
      const bytes = newUUID.match(/.{2}/g).map((b) => parseInt(b, 16));
      return byteArrayToUrlSafeBase64(bytes);
    } catch (e) {
      // namespace is not a UUID
      return '';
    }
  }, [customString, namespace]);

  return (
    <Modal size="lg" show={show} onHide={onCancel}>
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
              onChange={(e) => setNamespace(e.target.value)}
              isValid={namespace !== '' && newDeviceId !== ''}
              isInvalid={namespace !== '' && newDeviceId === ''}
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
              onChange={(e) => setCustomString(e.target.value)}
            />
          </Form.Group>
        </Form>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button
          variant="primary"
          onClick={() => onConfirm(newDeviceId)}
          disabled={newDeviceId === ''}
        >
          Generate ID
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

const RegisterDevicePage = ({ astarte, history }) => {
  const [deviceId, setDeviceId] = useState('');
  const [deviceSecret, setDeviceSecret] = useState('');
  const [sendIntrospection, setSendIntrospection] = useState(false);
  const [introspectionInterfaces, setIntrospectionInterfaces] = useState(new Map());
  const [isRegisteringDevice, setRegisteringDevice] = useState(false);
  const [showNamespaceModal, setShowNamespaceModal] = useState(false);
  const [showCredentialSecretModal, setShowCredentialSecretModal] = useState(false);

  const registrationAlerts = useAlerts();

  const byteArray = urlSafeBase64ToByteArray(deviceId);
  const isValidDeviceId = byteArray.length === 17 && byteArray[16] === 0;

  const generateRandomUUID = useCallback(() => {
    const newUUID = uuidv4().replace(/-/g, '');
    const bytes = newUUID.match(/.{2}/g).map((b) => parseInt(b, 16));
    const newDeviceID = byteArrayToUrlSafeBase64(bytes);

    setDeviceId(newDeviceID);
  }, []);

  const registerDevice = (e) => {
    e.preventDefault();

    const params = { deviceId };
    if (sendIntrospection) {
      params.introspection = introspectionInterfaces;
    }

    setRegisteringDevice(true);

    astarte
      .registerDevice(params)
      .then((registeredDevice) => {
        const secret = registeredDevice.credentials_secret;
        setRegisteringDevice(false);
        setDeviceSecret(secret);
        setShowCredentialSecretModal(true);
      })
      .catch((err) => {
        setRegisteringDevice(false);
        registrationAlerts.showError(`Couldn't register device: ${err.message}`);
      });
  };

  const addInterfaceToIntrospection = (interfaceDescriptor) => {
    const introspection = new Map(introspectionInterfaces);
    introspection.set(interfaceDescriptor.name, interfaceDescriptor);
    setIntrospectionInterfaces(introspection);
  };

  const removeIntrospectionInterface = (interfaceDescriptor) => {
    const introspection = new Map(introspectionInterfaces);
    introspection.delete(interfaceDescriptor.name);
    setIntrospectionInterfaces(introspection);
  };

  return (
    <SingleCardPage title="Register Device" backLink="/devices">
      <registrationAlerts.Alerts />
      <Form onSubmit={registerDevice}>
        <Form.Row className="mb-2">
          <Form.Group as={Col} controlId="deviceIdInput">
            <Form.Label>Device ID</Form.Label>
            <Form.Control
              type="text"
              className="text-monospace"
              placeholder="Your device ID"
              value={deviceId}
              onChange={(e) => setDeviceId(e.target.value)}
              autoComplete="off"
              required
              isValid={deviceId !== '' && isValidDeviceId}
              isInvalid={deviceId !== '' && !isValidDeviceId}
            />
            <Form.Control.Feedback type="invalid">
              Device ID must be a unique 128 bit URL-encoded base64 (without padding) string.
            </Form.Control.Feedback>
          </Form.Group>
          <Form.Group as={ColNoLabel}>
            <Button variant="secondary" className="mx-1" onClick={generateRandomUUID}>
              Generate random ID
            </Button>
            <Button
              variant="secondary"
              className="mx-1"
              onClick={() => setShowNamespaceModal(true)}
            >
              Generate from name...
            </Button>
          </Form.Group>
        </Form.Row>
        <Form.Group controlId="sendIntrospectionInput" className={sendIntrospection && 'mb-0'}>
          <Form.Check
            type="checkbox"
            label="Declare initial introspection"
            checked={sendIntrospection}
            onChange={(e) => setSendIntrospection(e.target.checked)}
          />
        </Form.Group>
        {sendIntrospection && (
          <InstrospectionTable
            interfaces={introspectionInterfaces}
            onAddInterface={addInterfaceToIntrospection}
            onRemoveInterface={removeIntrospectionInterface}
          />
        )}
        <Form.Row className="flex-row-reverse pr-2">
          <Button
            variant="primary"
            type="submit"
            disabled={!isValidDeviceId || isRegisteringDevice}
          >
            {isRegisteringDevice && (
              <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
            )}
            Register device
          </Button>
        </Form.Row>
      </Form>
      <NamespaceModal
        show={showNamespaceModal}
        onCancel={() => setShowNamespaceModal(false)}
        onConfirm={(newDeviceId) => {
          setShowNamespaceModal(false);
          setDeviceId(newDeviceId);
        }}
      />
      <CredentialSecretModal
        show={showCredentialSecretModal}
        secret={deviceSecret}
        onConfirm={() => history.push('/devices')}
      />
    </SingleCardPage>
  );
};

export default RegisterDevicePage;
