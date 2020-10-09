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

import React, { useEffect, useState, useCallback } from 'react';
import { Button, Modal, OverlayTrigger, Spinner, Table, Tooltip } from 'react-bootstrap';
import AstarteClient, { AstarteDevice } from 'astarte-client';

import { Link } from 'react-router-dom';
import SingleCardPage from './ui/SingleCardPage';

const CircleIcon = React.forwardRef<HTMLElement, React.HTMLProps<HTMLElement>>((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));

interface ConfirmDeviceRemovalModal {
  deviceName: string;
  groupName: string;
  isLastDevice: boolean;
  isRemoving: boolean;
  show: boolean;
  onCancel: () => void;
  onRemove: () => void;
}

const ConfirmDeviceRemovalModal = ({
  deviceName,
  groupName,
  isLastDevice,
  isRemoving,
  show,
  onCancel,
  onRemove,
}: ConfirmDeviceRemovalModal): React.ReactElement => (
  <div
    onKeyDown={(e) => {
      if (e.key === 'Enter' && !isRemoving) {
        onRemove();
      }
    }}
  >
    <Modal size="lg" show={show} onHide={onCancel}>
      <Modal.Header closeButton>
        <Modal.Title>Warning</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        {isLastDevice && (
          <p>This is the last device in the group. Removing this device will delete the group</p>
        )}
        <p>{`Remove device "${deviceName}" from group "${groupName}"?`}</p>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button variant="danger" disabled={isRemoving} onClick={onRemove}>
          {isRemoving && <Spinner className="mr-2" size="sm" animation="border" role="status" />}
          Remove
        </Button>
      </Modal.Footer>
    </Modal>
  </div>
);

const deviceTableRow = (
  device: AstarteDevice,
  index: number,
  showModal: (d: AstarteDevice) => void,
) => {
  let colorClass;
  let lastEvent;
  let tooltipText;

  if (device.isConnected) {
    tooltipText = 'Connected';
    colorClass = 'icon-connected';
    lastEvent = `Connected on ${(device.lastConnection as Date).toLocaleString()}`;
  } else if (device.lastConnection) {
    tooltipText = 'Disconnected';
    colorClass = 'icon-disconnected';
    lastEvent = `Disconnected on ${(device.lastDisconnection as Date).toLocaleString()}`;
  } else {
    tooltipText = 'Never connected';
    colorClass = 'icon-never-connected';
    lastEvent = 'Never connected';
  }

  return (
    <tr key={index}>
      <td>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 400 }}
          overlay={<Tooltip id={`tooltip-icon-${index}`}>{tooltipText}</Tooltip>}
        >
          <CircleIcon className={colorClass} />
        </OverlayTrigger>
      </td>
      <td className={device.hasNameAlias ? '' : 'text-monospace'}>
        <Link to={`/devices/${device.id}`}>{device.name}</Link>
      </td>
      <td>{lastEvent}</td>
      <td>
        <OverlayTrigger
          placement="left"
          delay={{ show: 150, hide: 400 }}
          overlay={<Tooltip id={`tooltip-remove-button-${index}`}>Remove from group</Tooltip>}
        >
          <Button
            as="i"
            variant="danger"
            className="fas fa-times"
            onClick={() => showModal(device)}
          />
        </OverlayTrigger>
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

interface Props {
  astarte: AstarteClient;
  history: any;
  groupName: string;
}

const GroupDevicesPage = ({ astarte, history, groupName }: Props): React.ReactElement => {
  const [phase, setPhase] = useState<'ok' | 'loading' | 'err'>('loading');
  const [devices, setDevices] = useState<AstarteDevice[] | null>(null);
  const [selectedDevice, setSelectedDevice] = useState<AstarteDevice | null>(null);
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [isRemovingDevice, setIsRemovingDevice] = useState(false);

  const fetchDevices = useCallback(() => {
    const handleDevicesRequest = (newDevices: AstarteDevice[]) => {
      setDevices(newDevices);
      setPhase('ok');
    };
    const handleDevicesError = () => {
      setPhase('err');
    };
    astarte
      .getDevicesInGroup({
        groupName,
        details: true,
      })
      .then(handleDevicesRequest)
      .catch(handleDevicesError);
  }, [astarte, groupName, setPhase, setDevices]);

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
    astarte
      .removeDeviceFromGroup({
        groupName,
        deviceId: selectedDevice.id,
      })
      .finally(() => {
        if (devices?.length === 1) {
          history.push({ pathname: '/groups' });
        } else {
          setIsRemovingDevice(false);
          setIsModalVisible(false);
          fetchDevices();
        }
      });
  }, [
    astarte,
    setIsRemovingDevice,
    setIsModalVisible,
    fetchDevices,
    groupName,
    selectedDevice,
    devices,
    history,
  ]);

  useEffect(() => {
    fetchDevices();
  }, [fetchDevices]);

  let innerHTML;

  switch (phase) {
    case 'ok':
      const deviceList = devices as AstarteDevice[];
      innerHTML = (
        <>
          <h5 className="mt-1 mb-3">
            Devices in group
            {groupName}
          </h5>
          {deviceTable(deviceList, showModal)}
        </>
      );
      break;

    case 'err':
      innerHTML = <p>Couldn&apos;t load devices in group</p>;
      break;

    default:
      innerHTML = <Spinner animation="border" role="status" />;
      break;
  }

  const selectedDeviceName = selectedDevice?.name as string;
  return (
    <SingleCardPage title="Group Devices" backLink="/groups">
      {innerHTML}
      <ConfirmDeviceRemovalModal
        deviceName={selectedDeviceName}
        groupName={groupName}
        isLastDevice={devices?.length === 1}
        isRemoving={isRemovingDevice}
        show={isModalVisible}
        onCancel={closeModal}
        onRemove={removeDevice}
      />
    </SingleCardPage>
  );
};

export default GroupDevicesPage;
