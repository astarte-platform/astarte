/*
   This file is part of Astarte.

   Copyright 2020-2024 SECO Mind Srl

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

import React, { useCallback, useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { v4 as uuidv4, v5 as uuidv5 } from 'uuid';
import { Button, Col, Form, Row, Spinner, Stack, Table } from 'react-bootstrap';
import type { AstarteDevice, AstarteInterfaceDescriptor } from 'astarte-client';
import semver from 'semver';

import Icon from './components/Icon';
import ConfirmModal from './components/modals/Confirm';
import FormModal from './components/modals/Form';
import SingleCardPage from './ui/SingleCardPage';
import { byteArrayToUrlSafeBase64, urlSafeBase64ToByteArray } from './Base64';
import { AlertsBanner, useAlerts } from './AlertManager';
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

const ColNoLabel = ({ children, ...otherProps }: ColNoLabelProps): React.ReactElement => (
  <Form.Group as={Col} {...otherProps}>
    <Form.Label />
    {children}
  </Form.Group>
);

interface InterfaceIntrospectionRowProps {
  interfaceDescriptor: AstarteInterfaceDescriptor;
  onRemove: () => void;
}

const ChangeSource = {
  SelectOptions: 'selectOptions',
  Input: 'input',
};

const InterfaceIntrospectionRow = ({
  interfaceDescriptor,
  onRemove,
}: InterfaceIntrospectionRowProps): React.ReactElement => (
  <tr>
    <td>{interfaceDescriptor.name}</td>
    <td>{interfaceDescriptor.major}</td>
    <td>{interfaceDescriptor.minor}</td>
    <td>
      <Icon icon="erase" onClick={onRemove} />
    </td>
  </tr>
);

interface IntrospectionControlRowProps {
  onAddInterface: (interfaceDescriptor: AstarteInterfaceDescriptor) => void;
  interfaces: Map<AstarteInterfaceDescriptor['name'], AstarteInterfaceDescriptor>;
}

const IntrospectionControlRow = ({
  onAddInterface,
  interfaces,
}: IntrospectionControlRowProps): React.ReactElement => {
  const initialState: AstarteInterfaceDescriptor = {
    name: '',
    major: 0,
    minor: 1,
  };
  const astarte = useAstarte();
  const [selectedInterfaceOption, setSelectedInterfaceOption] = useState<string>('');
  const [interfaceOptions, setInterfaceOptions] = useState<{ value: string; label: string }[]>([]);
  const [interfaceDescriptor, setInterfaceDescriptor] =
    useState<AstarteInterfaceDescriptor>(initialState);
  const [selectedInterfaceData, setSelectedInterfaceData] = useState<AstarteInterfaceDescriptor[]>(
    [],
  );
  const [greaterRealmManagementVersion, setGreaterRealmManagementVersion] = useState(false);
  const [hasSelectedInterface, setSelectedInterface] = useState<boolean>(false);
  const [disableVersionInput, setDisableVersionInput] = useState<boolean>(false);
  const [loadingInterfaceData, setLoadingInterfaceData] = useState(true);
  const canShowInterfaceMinorAndMajor = hasSelectedInterface || !greaterRealmManagementVersion;

  const handleNameChange = (value: string, from: string) => {
    if (value != '') {
      setSelectedInterface(true);
    }
    if (from === ChangeSource.SelectOptions) {
      const selectedInterface = selectedInterfaceData[Number(value)];
      if (selectedInterface) {
        setInterfaceDescriptor({
          name: selectedInterface.name,
          major: selectedInterface.major,
          minor: selectedInterface.minor,
        });
        setSelectedInterfaceOption(value.toString());
      }
    } else {
      setInterfaceDescriptor((state) => ({ ...state, name: value }));
    }
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

  const isValidInterfaceData = (interfacesData: any): interfacesData is Array<any> =>
    Array.isArray(interfacesData) && interfacesData.every((detail) => typeof detail === 'object');

  const mapInterfacesData = (interfacesData: any[]): AstarteInterfaceDescriptor[] =>
    interfacesData.map((interfaceDetail: any) => ({
      name: interfaceDetail.interface_name,
      major: interfaceDetail.version_major,
      minor: interfaceDetail.version_minor,
    }));

  const fetchInterfacesInfo = useCallback(async () => {
    setLoadingInterfaceData(true);

    try {
      const realmManagementVersion = await astarte.client.getRealmManagementVersion();
      const interfacesData = await astarte.client.getInterfaces();

      const isRealmVersionValid = semver.satisfies(realmManagementVersion, '>=1.3.*', {
        includePrerelease: true,
      });
      const isInterfaceDataValid = isValidInterfaceData(interfacesData);

      if (isRealmVersionValid && isInterfaceDataValid) {
        const fetchedInterfaces = mapInterfacesData(interfacesData);
        setGreaterRealmManagementVersion(true);
        setSelectedInterfaceData(fetchedInterfaces);
        setDisableVersionInput(true);

        return fetchedInterfaces;
      } else {
        setGreaterRealmManagementVersion(false);
        setDisableVersionInput(false);
      }
    } finally {
      setLoadingInterfaceData(false);
    }
    return [];
  }, [astarte.client]);

  useEffect(() => {
    const loadOptions = async () => {
      const interfaces = await fetchInterfacesInfo();
      if (interfaces) {
        const interfaceOptions = interfaces.map((iface) => ({
          value: iface.name,
          label: `${iface.name} (v${iface.major}.${iface.minor})`,
        }));
        setInterfaceOptions(interfaceOptions);
      }
    };
    loadOptions();
  }, [fetchInterfacesInfo]);

  const handleAddIntrospectionInterfaces = (interfaceDescriptor: AstarteInterfaceDescriptor) => {
    onAddInterface(interfaceDescriptor);
    setInterfaceDescriptor(initialState);
    setSelectedInterfaceOption('');
  };

  const selectedInterfaceIsDisabled = (label: string): boolean => {
    return Array.from(interfaces.values()).some((descriptor: AstarteInterfaceDescriptor) => {
      const fullName = `${descriptor.name} (v${descriptor.major}.${descriptor.minor})`;
      return fullName == label;
    });
  };

  return (
    <tr>
      <td className="w-50">
        {greaterRealmManagementVersion ? (
          <Form.Select
            value={selectedInterfaceOption}
            onChange={(e) =>
              handleNameChange((e.target.selectedIndex - 1).toString(), ChangeSource.SelectOptions)
            }
            className="form-control"
          >
            <option value="" disabled>
              Interface name
            </option>
            {interfaceOptions.map((option, index) => (
              <option
                key={index}
                value={index.toString()}
                disabled={selectedInterfaceIsDisabled(option.label)}
              >
                {option.label}
              </option>
            ))}
          </Form.Select>
        ) : (
          <Form.Control
            type="text"
            placeholder="Interface name"
            value={interfaceDescriptor.name}
            onChange={(e) => handleNameChange(e.target.value, ChangeSource.Input)}
          />
        )}
      </td>
      {interfaceDescriptor.name !== '' && canShowInterfaceMinorAndMajor && !loadingInterfaceData ? (
        <>
          <td>
            <Form.Control
              type="number"
              min="0"
              value={interfaceDescriptor.major}
              onChange={handleMajorChange}
              disabled={disableVersionInput}
            />
          </td>
          <td>
            <Form.Control
              type="number"
              min="0"
              value={interfaceDescriptor.minor}
              onChange={handleMinorChange}
              disabled={disableVersionInput}
            />
          </td>
          <td>
            <Button
              variant="secondary"
              disabled={interfaceDescriptor.name === ''}
              onClick={() => handleAddIntrospectionInterfaces(interfaceDescriptor)}
            >
              Add
            </Button>
          </td>
        </>
      ) : (
        <td colSpan={3}></td>
      )}
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
      <IntrospectionControlRow onAddInterface={onAddInterface} interfaces={interfaces} />
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
              '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
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
  const [registrationAlerts, registrationAlertsController] = useAlerts();
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
        const deviceRegistrationLimitReached =
          err?.response?.data?.errors?.error_name?.[0] === 'device_registration_limit_reached';
        const errorMessage = deviceRegistrationLimitReached
          ? `The device registration limit was reached and there are too many registered devices already.`
          : err.message;
        setRegisteringDevice(false);
        registrationAlertsController.showError(`Could not register the device. ${errorMessage}`);
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
      <AlertsBanner alerts={registrationAlerts} />
      <Form onSubmit={registerDevice}>
        <Stack gap={3}>
          <Row className="d-flex align-items-end flex-wrap g-3">
            <Form.Group
              xs={12}
              md="auto"
              className="flex-grow-1"
              as={Col}
              controlId="deviceIdInput"
            >
              <Form.Label>Device ID</Form.Label>
              <Form.Control
                type="text"
                className="font-monospace"
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
            <ColNoLabel as={Col} xs={12} md="auto" className="d-flex flex-column flex-md-row">
              <Button variant="secondary" onClick={generateRandomUUID}>
                Generate random ID
              </Button>
            </ColNoLabel>
            <ColNoLabel as={Col} xs={12} md="auto" className="d-flex flex-column flex-md-row">
              <Button variant="secondary" onClick={() => setShowNamespaceModal(true)}>
                Generate from name...
              </Button>
            </ColNoLabel>
          </Row>
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
          <div className="d-flex flex-column flex-md-row-reverse">
            <Button
              variant="primary"
              type="submit"
              disabled={!isValidDeviceId || isRegisteringDevice}
              hidden={!astarte.token?.can('pairing', 'POST', '/agent/devices')}
            >
              {isRegisteringDevice && (
                <Spinner as="span" size="sm" animation="border" role="status" className="me-2" />
              )}
              Register device
            </Button>
          </div>
        </Stack>
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
            <Icon icon="copyPaste" onClick={pasteSecret} style={{ cursor: 'copy' }} />
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
