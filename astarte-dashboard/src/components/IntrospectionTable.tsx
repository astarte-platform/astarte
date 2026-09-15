/*
   This file is part of Astarte.

   Copyright 2026 SECO Mind Srl

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

import React, { useCallback, useEffect, useState } from 'react';
import { Button, Form, Table } from 'react-bootstrap';
import type { AstarteInterfaceDescriptor } from 'astarte-client';
import semver from 'semver';

import Icon from './Icon';
import { useAstarte } from '../AstarteManager';

const ChangeSource = {
  SelectOptions: 'selectOptions',
  Input: 'input',
};

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
    if (value !== '') {
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

  const selectedInterfaceIsDisabled = (label: string): boolean =>
    Array.from(interfaces.values()).some((descriptor: AstarteInterfaceDescriptor) => {
      const fullName = `${descriptor.name} (v${descriptor.major}.${descriptor.minor})`;
      return fullName === label;
    });

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

interface IntrospectionTableProps {
  interfaces: Map<AstarteInterfaceDescriptor['name'], AstarteInterfaceDescriptor>;
  onAddInterface: (interfaceDescriptor: AstarteInterfaceDescriptor) => void;
  onRemoveInterface: (interfaceDescriptor: AstarteInterfaceDescriptor) => void;
}

const IntrospectionTable = ({
  interfaces,
  onAddInterface,
  onRemoveInterface,
}: IntrospectionTableProps): React.ReactElement => (
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

export default IntrospectionTable;
