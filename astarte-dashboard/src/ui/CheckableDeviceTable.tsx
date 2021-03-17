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

import React, { useCallback, useMemo } from 'react';
import { Form, Table } from 'react-bootstrap';
import { AstarteDevice } from 'astarte-client';

interface HighlightProps {
  text: string;
  word?: string;
}

const Highlight = ({ text, word }: HighlightProps): React.ReactElement => {
  if (!word) {
    return <span>{text}</span>;
  }

  return (
    <>
      {text.split(word).reduce(
        (prev: React.ReactElement[], current, index) => [
          ...prev,
          <span key={index} className="bg-warning text-dark">
            {word}
          </span>,
          <span>{current}</span>,
        ],
        [],
      )}
    </>
  );
};

interface DeviceTableRowProps {
  deviceId: string;
  deviceAliases: Array<[string, string]>;
  filter?: string;
  selected: boolean;
  onToggleDevice: (deviceId: string, checked: boolean) => void;
}

const DeviceTableRow = ({
  deviceId,
  deviceAliases,
  filter,
  selected,
  onToggleDevice,
}: DeviceTableRowProps) => {
  const onToggleChange = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      const { checked } = event.target;
      onToggleDevice(deviceId, checked);
    },
    [deviceId, onToggleDevice],
  );
  return (
    <tr>
      <td>
        <Form.Check
          id={`device-${deviceId}`}
          type="checkbox"
          checked={selected}
          onChange={onToggleChange}
        />
      </td>
      <td className="text-monospace">
        <Highlight text={deviceId} word={filter} />
      </td>
      <td>
        <ul className="list-unstyled">
          {deviceAliases.map(([aliasTag, alias]) => (
            <li key={aliasTag}>
              <Highlight text={alias} word={filter} />
            </li>
          ))}
        </ul>
      </td>
    </tr>
  );
};

interface CheckableDeviceTableProps {
  devices: AstarteDevice[];
  filter?: string;
  selectedDevices: Set<AstarteDevice['id']>;
  onToggleDevice: DeviceTableRowProps['onToggleDevice'];
}

const CheckableDeviceTable = ({
  devices,
  filter,
  selectedDevices,
  onToggleDevice,
}: CheckableDeviceTableProps): React.ReactElement => {
  const filteredDevices = useMemo(() => {
    if (filter) {
      return devices.filter((device) => {
        const aliases = Array.from(device.aliases.values());
        return (
          device.id.includes(filter) || aliases.filter((alias) => alias.includes(filter)).length > 0
        );
      });
    }
    return devices;
  }, [devices, filter]);

  if (!filteredDevices.length) {
    return <p>No device matched the current filter</p>;
  }

  return (
    <Table responsive hover>
      <thead>
        <tr>
          <th>Selected</th>
          <th>Device ID</th>
          <th>Aliases</th>
        </tr>
      </thead>
      <tbody>
        {filteredDevices.map((device) => (
          <DeviceTableRow
            key={device.id}
            deviceId={device.id}
            deviceAliases={Array.from(device.aliases.entries())}
            selected={selectedDevices.has(device.id)}
            filter={filter}
            onToggleDevice={onToggleDevice}
          />
        ))}
      </tbody>
    </Table>
  );
};

export default CheckableDeviceTable;
