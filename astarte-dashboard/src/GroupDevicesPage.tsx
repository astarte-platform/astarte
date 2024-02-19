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

import React, { useState, useCallback } from 'react';
import { Container, Spinner, Table } from 'react-bootstrap';
import type { AstarteDevice } from 'astarte-client';
import { Link, useNavigate, useParams } from 'react-router-dom';

import Empty from './components/Empty';
import Icon from './components/Icon';
import ConfirmModal from './components/modals/Confirm';
import SingleCardPage from './ui/SingleCardPage';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import { useAstarte } from './AstarteManager';

const deviceTableRow = (
  device: AstarteDevice,
  index: number,
  showModal: (d: AstarteDevice) => void,
) => {
  let icon;
  let iconTooltip;
  let lastEvent;
  let statusLabel;

  if (device.isConnected) {
    icon = 'statusConnected' as const;
    iconTooltip = 'Connected';
    statusLabel = 'Connected';
    lastEvent = `Connected on ${(device.lastConnection as Date).toLocaleString()}`;
  } else if (device.lastConnection) {
    icon = 'statusDisconnected' as const;
    iconTooltip = 'Disconnected';
    statusLabel = 'Disconnected';
    lastEvent = `Disconnected on ${(device.lastDisconnection as Date).toLocaleString()}`;
  } else {
    icon = 'statusNeverConnected' as const;
    iconTooltip = 'Never connected';
    statusLabel = 'Never connected';
    lastEvent = 'Never connected';
  }

  if (device.deletionInProgress) {
    icon = 'statusInDeletion' as const;
    iconTooltip = 'In deletion';
    statusLabel = 'In deletion';
  }

  return (
    <tr key={index}>
      <td>
        <Icon className="me-2" icon={icon} tooltip={iconTooltip} tooltipPlacement="right" />
        <span>{statusLabel}</span>
      </td>
      <td className={device.hasNameAlias ? '' : 'font-monospace'}>
        <Link to={`/devices/${device.id}/edit`}>{device.name}</Link>
      </td>
      <td>{lastEvent}</td>
      <td>
        <Icon
          icon="delete"
          as="button"
          tooltip="Remove from group"
          tooltipPlacement="left"
          onClick={() => showModal(device)}
        />
      </td>
    </tr>
  );
};

const deviceTable = (deviceList: AstarteDevice[], showModal: (d: AstarteDevice) => void) => (
  <Table responsive>
    <thead>
      <tr>
        <th>Status</th>
        <th>Device handle</th>
        <th>Last connection event</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>{deviceList.map((device, index) => deviceTableRow(device, index, showModal))}</tbody>
  </Table>
);

const GroupDevicesPage = (): React.ReactElement => {
  const { groupName = '' } = useParams();
  const [selectedDevice, setSelectedDevice] = useState<AstarteDevice | null>(null);
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [isRemovingDevice, setIsRemovingDevice] = useState(false);
  const navigate = useNavigate();
  const astarte = useAstarte();

  const devicesFetcher = useFetch(() =>
    astarte.client.getDevicesInGroup({
      groupName,
      details: true,
    }),
  );

  const showModal = useCallback(
    (device: AstarteDevice) => {
      setSelectedDevice(device);
      setIsModalVisible(true);
    },
    [setSelectedDevice, setIsModalVisible],
  );

  const closeModal = useCallback(() => {
    setIsModalVisible(false);
  }, [setIsModalVisible]);

  const removeDevice = useCallback(() => {
    if (!selectedDevice) {
      return;
    }
    setIsRemovingDevice(true);
    astarte.client
      .removeDeviceFromGroup({
        groupName,
        deviceId: selectedDevice.id,
      })
      .finally(() => {
        if (devicesFetcher.value != null && devicesFetcher.value.length === 1) {
          navigate({ pathname: '/groups' });
        } else {
          setIsRemovingDevice(false);
          setIsModalVisible(false);
          devicesFetcher.refresh();
        }
      });
  }, [
    astarte.client,
    setIsRemovingDevice,
    setIsModalVisible,
    devicesFetcher.refresh,
    devicesFetcher.value,
    groupName,
    selectedDevice,
    navigate,
  ]);

  const selectedDeviceName = selectedDevice?.name as string;

  return (
    <SingleCardPage title="Group Devices" backLink="/groups">
      <h5 className="mt-1 mb-3">{`Devices in group ${groupName}`}</h5>
      <WaitForData
        data={devicesFetcher.value}
        status={devicesFetcher.status}
        fallback={
          <Container fluid className="text-center">
            <Spinner animation="border" role="status" />
          </Container>
        }
        errorFallback={
          <Empty title="Couldn't load devices in group" onRetry={devicesFetcher.refresh} />
        }
      >
        {(devices) => deviceTable(devices, showModal)}
      </WaitForData>
      {isModalVisible && (
        <ConfirmModal
          title="Warning"
          confirmLabel="Remove"
          confirmVariant="danger"
          onCancel={closeModal}
          onConfirm={removeDevice}
          isConfirming={isRemovingDevice}
        >
          {devicesFetcher.value != null && devicesFetcher.value.length === 1 && (
            <p>This is the last device in the group. Removing this device will delete the group</p>
          )}
          <p>
            Remove device <b>{selectedDeviceName}</b> from group <b>{groupName}</b>?
          </p>
        </ConfirmModal>
      )}
    </SingleCardPage>
  );
};

export default GroupDevicesPage;
