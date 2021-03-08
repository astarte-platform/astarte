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

import React, { useCallback, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { v4 as uuidv4, v5 as uuidv5 } from 'uuid';
import { Button, Col, Form, Spinner, Table } from 'react-bootstrap';
import type { AstarteDevice, AstarteInterfaceDescriptor } from 'astarte-client';

import ConfirmModal from './components/modals/Confirm';
import FormModal from './components/modals/Form';
import SingleCardPage from './ui/SingleCardPage';
import { byteArrayToUrlSafeBase64, urlSafeBase64ToByteArray } from './Base64';
import { useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';

/* TODO use clipboard API
 * Right now the 'clipboard-write' is supported
 * only on chromium browser.
 * document.execCommand("copy") is deprecated but
 * for now it's the only reliable way to copy to clipboard
 */
function pasteSecret() {
  const secretCode = document.querySelector('#secret-code');
  if (secretCode == null) {
    return;
  }
  const selection = window.getSelection();
  if (selection == null) {
    return;
  }
  if (selection.rangeCount > 0) {
    selection.removeAllRanges();
  }
  const range = document.createRange();
  range.selectNode(secretCode);
  selection.addRange(range);
  document.execCommand('copy');
}

type ColNoLabelProps = React.ComponentProps<typeof Col>;

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const ColNoLabel = ({ sm, className = '', ...otherProps }: ColNoLabelProps): React.ReactElement => (
  <Col sm="auto" className={'col-no-label '.concat(className)} {...otherProps} />
);

interface InterfaceIntrospectionRowProps {
  interfaceDescriptor: AstarteInterfaceDescriptor;
  onRemove: () => void;
}

const InterfaceIntrospectionRow = ({
  interfaceDescriptor,
  onRemove,
}: InterfaceIntrospectionRowProps): React.ReactElement => (
  <tr>
    <td>{interfaceDescriptor.name}</td>
    <td>{interfaceDescriptor.major}</td>
    <td>{interfaceDescriptor.minor}</td>
    <td>
      <i className="fas fa-eraser color-red action-icon" onClick={onRemove} />
    </td>
  </tr>
);

interface IntrospectionControlRowProps {
  onAddInterface: (interfaceDescriptor: AstarteInterfaceDescriptor) => void;
}

const IntrospectionControlRow = ({
  onAddInterface,
}: IntrospectionControlRowProps): React.ReactElement => {
  const initialState: AstarteInterfaceDescriptor = {
    name: '',
    major: 0,
    minor: 1,
  };

  const [interfaceDescriptor, setInterfaceDescriptor] = useState<AstarteInterfaceDescriptor>(
    initialState,
  );

  const handleNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setInterfaceDescriptor((state) => ({ ...state, name: value }));
  };

  const handleMajorChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
    setInterfaceDescriptor((state) => ({
      ...state,
      major: parseInt(value, 10) || 0,
    }));
  };

  const handleMinorChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { value } = e.target;
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

interface InstrospectionTableProps {
  interfaces: Map<AstarteInterfaceDescriptor['name'], AstarteInterfaceDescriptor>;
  onAddInterface: (interfaceDescriptor: AstarteInterfaceDescriptor) => void;
  onRemoveInterface: (interfaceDescriptor: AstarteInterfaceDescriptor) => void;
}

const InstrospectionTable = ({
  interfaces,
  onAddInterface,
  onRemoveInterface,
}: InstrospectionTableProps): React.ReactElement => (
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
          interfaceDescriptor={interfaceDescriptor}
          onRemove={() => onRemoveInterface(interfaceDescriptor)}
        />
      ))}
      <IntrospectionControlRow onAddInterface={onAddInterface} />
    </tbody>
  </Table>
);

interface NamespaceModalProps {
  onCancel: () => void;
  onConfirm: (deviceId: string) => void;
}

const NamespaceModal = ({ onCancel, onConfirm }: NamespaceModalProps) => {
  const handleConfirm = useCallback(
    (formData: { userNamespace: string; userString?: string }) => {
      const newUUID = uuidv5(formData.userString || '', formData.userNamespace).replace(/-/g, '');
      const bytes = (newUUID.match(/.{2}/g) as RegExpMatchArray).map((b) => parseInt(b, 16));
      const deviceId = byteArrayToUrlSafeBase64(bytes);
      onConfirm(deviceId);
    },
    [onConfirm],
  );

  return (
    <FormModal
      title="Generate from name"
      confirmLabel="Generate ID"
      onCancel={onCancel}
      onConfirm={handleConfirm}
      schema={{
        type: 'object',
        required: ['userNamespace'],
        properties: {
          userNamespace: {
            title: 'Namespace UUID in canonical text format',
            type: 'string',
            pattern:
              '^[0-9a-fA-F]{8}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{12}$',
          },
          userString: {
            title: 'Name',
            type: 'string',
          },
        },
      }}
      uiSchema={{
        userNamespace: {
          'ui:autofocus': true,
          'ui:placeholder': 'e.g.: 753ffc99-dd9d-4a08-a07e-9b0d6ce0bc82',
        },
        userString: {
          'ui:placeholder': 'e.g.: my device',
        },
      }}
      transformErrors={(errors) =>
        errors.map((error) => {
          if (error.property === '.userNamespace' && error.name === 'pattern') {
            return { ...error, message: 'The namespace must be a valid UUID' };
          }
          return error;
        })
      }
    />
  );
};

export default (): React.ReactElement => {
  const searchQuery = new URLSearchParams(useLocation().search);
  const initialDeviceId = searchQuery.get('deviceId') || '';
  const [deviceId, setDeviceId] = useState<AstarteDevice['id']>(initialDeviceId);
  const [deviceSecret, setDeviceSecret] = useState<string>('');
  const [shouldSendIntrospection, setShouldSendIntrospection] = useState(false);
  const [introspectionInterfaces, setIntrospectionInterfaces] = useState<
    Map<AstarteInterfaceDescriptor['name'], AstarteInterfaceDescriptor>
  >(new Map());
  const [isRegisteringDevice, setRegisteringDevice] = useState(false);
  const [showNamespaceModal, setShowNamespaceModal] = useState(false);
  const [showCredentialSecretModal, setShowCredentialSecretModal] = useState(false);
  const registrationAlerts = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();

  const byteArray = urlSafeBase64ToByteArray(deviceId);
  const isValidDeviceId = byteArray.length === 17 && byteArray[16] === 0;

  const generateRandomUUID = useCallback(() => {
    const newUUID = uuidv4().replace(/-/g, '');
    const bytes = (newUUID.match(/.{2}/g) as RegExpMatchArray).map((b) => parseInt(b, 16));
    const newDeviceID = byteArrayToUrlSafeBase64(bytes);
    setDeviceId(newDeviceID);
  }, []);

  const registerDevice = (e: React.FormEvent<HTMLElement>) => {
    e.preventDefault();
    const deviceIntrospection = Object.fromEntries(introspectionInterfaces);
    const params = {
      deviceId,
      introspection: shouldSendIntrospection ? deviceIntrospection : undefined,
    };
    setRegisteringDevice(true);
    astarte.client
      .registerDevice(params)
      .then(({ credentialsSecret }) => {
        setRegisteringDevice(false);
        setDeviceSecret(credentialsSecret);
        setShowCredentialSecretModal(true);
      })
      .catch((err) => {
        setRegisteringDevice(false);
        registrationAlerts.showError(`Couldn't register device: ${err.message}`);
      });
  };

  const addInterfaceToIntrospection = (interfaceDescriptor: AstarteInterfaceDescriptor) => {
    const introspection = new Map(introspectionInterfaces);
    introspection.set(interfaceDescriptor.name, interfaceDescriptor);
    setIntrospectionInterfaces(introspection);
  };

  const removeIntrospectionInterface = (interfaceDescriptor: AstarteInterfaceDescriptor) => {
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
              onChange={(e: React.ChangeEvent<HTMLInputElement>) => setDeviceId(e.target.value)}
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
        <Form.Group
          controlId="sendIntrospectionInput"
          className={shouldSendIntrospection ? 'mb-0' : ''}
        >
          <Form.Check
            type="checkbox"
            label="Declare initial introspection"
            checked={shouldSendIntrospection}
            onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
              setShouldSendIntrospection(e.target.checked)
            }
          />
        </Form.Group>
        {shouldSendIntrospection && (
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
      {showNamespaceModal && (
        <NamespaceModal
          onCancel={() => setShowNamespaceModal(false)}
          onConfirm={(newDeviceId: string) => {
            setShowNamespaceModal(false);
            setDeviceId(newDeviceId);
          }}
        />
      )}
      {showCredentialSecretModal && (
        <ConfirmModal
          title="Device Registered!"
          confirmLabel="OK"
          onConfirm={() => navigate('/devices')}
        >
          <span>The device credential secret is</span>
          <pre className="my-2">
            <code id="secret-code" className="m-1 p-2 bg-light" style={{ fontSize: '1.2em' }}>
              {deviceSecret}
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
        </ConfirmModal>
      )}
    </SingleCardPage>
  );
};
