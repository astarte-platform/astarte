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
import { AstarteDevice } from 'astarte-client';

import { Link } from 'react-router-dom';
import SingleCardPage from './ui/SingleCardPage';

const deviceTableRow = (device, index, showModal) => {
  let colorClass;
  let lastEvent;
  let tooltipText;

  if (device.isConnected) {
    tooltipText = 'Connected';
    colorClass = 'icon-connected';
    lastEvent = `Connected on ${device.lastConnection.toLocaleString()}`;
  } else if (device.lastConnection) {
    tooltipText = 'Disconnected';
    colorClass = 'icon-disconnected';
    lastEvent = `Disconnected on ${device.lastDisconnection.toLocaleString()}`;
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
          style={{
            backgroundColor: 'rgba(255, 100, 100, 0.85)',
            padding: '2px 10px',
            color: 'white',
            borderRadius: 3,
          }}
          overlay={<Tooltip>{tooltipText}</Tooltip>}
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
          style={{
            backgroundColor: 'rgba(255, 100, 100, 0.85)',
            padding: '2px 10px',
            color: 'white',
            borderRadius: 3,
          }}
          overlay={<Tooltip>Remove from group</Tooltip>}
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

const deviceTable = (deviceList, showModal) => (
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

const GroupDevicesPage = ({ astarte, history, groupName }) => {
  const [phase, setPhase] = useState('loading');
  const [devices, setDevices] = useState(null);
  const [selectedDevice, setSelectedDevice] = useState(null);
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [isRemovingDevice, setIsRemovingDevice] = useState(false);

  const fetchDevices = useCallback(() => {
    const handleDevicesRequest = (response) => {
      const newDevices = response.data.map((device) => AstarteDevice.fromObject(device));
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
    (device) => {
      setSelectedDevice(device);
      setIsModalVisible(true);
    },
    [setSelectedDevice, setIsModalVisible],
  );

  const closeModal = useCallback(() => {
    setIsModalVisible(false);
  }, [setIsModalVisible]);

  const removeDevice = useCallback(() => {
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
      innerHTML = (
        <>
          <h5 className="mt-1 mb-3">
            Devices in group
            {groupName}
          </h5>
          {deviceTable(devices, showModal)}
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

  return (
    <SingleCardPage title="Group Devices" backLink="/groups">
      {innerHTML}
      <ConfirmDeviceRemovalModal
        deviceName={selectedDevice?.name}
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

const CircleIcon = React.forwardRef((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));

const ConfirmDeviceRemovalModal = ({
  deviceName,
  groupName,
  isLastDevice,
  isRemoving,
  show,
  onCancel,
  onRemove,
}) => (
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

export default GroupDevicesPage;
