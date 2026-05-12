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

import React from 'react';
import { Button, Card } from 'react-bootstrap';

import type { AstarteDevice } from 'astarte-client';
import FullHeightCard from '../components/FullHeightCard';
import Icon from '../components/Icon';
import { useAstarte } from 'AstarteManager';

interface DeviceStatusProps {
  status: AstarteDevice['deviceStatus'];
}

const DeviceStatus = ({ status }: DeviceStatusProps): React.ReactElement => {
  let statusString;
  let icon;

  switch (status) {
    case 'connected':
      statusString = 'Connected';
      icon = 'statusConnected' as const;
      break;

    case 'disconnected':
      statusString = 'Disconnected';
      icon = 'statusDisconnected' as const;
      break;

    case 'in_deletion':
      statusString = 'In deletion';
      icon = 'statusInDeletion' as const;
      break;

    case 'never_connected':
    default:
      statusString = 'Never connected';
      icon = 'statusNeverConnected' as const;
      break;
  }

  return (
    <>
      <Icon icon={icon} className="me-1" />
      <span>{statusString}</span>
    </>
  );
};

interface DeviceInfoCardProps {
  device: AstarteDevice;
  onInhibitCredentialsClick: () => void;
  onEnableCredentialsClick: () => void;
  onWipeCredentialsClick: () => void;
  onDeleteDeviceClick: () => void;
}

const DeviceInfoCard = ({
  device,
  onInhibitCredentialsClick,
  onEnableCredentialsClick,
  onWipeCredentialsClick,
  onDeleteDeviceClick,
}: DeviceInfoCardProps): React.ReactElement => {
  const astarte = useAstarte();
  return (
    <FullHeightCard xs={12} md={6} className="mb-4">
      <Card.Header as="h5">Device Info</Card.Header>
      <Card.Body className="d-flex flex-column">
        <h6>Device ID</h6>
        <p className="font-monospace">{device.id}</p>
        <h6>Device name</h6>
        <p>{device.hasNameAlias ? device.name : 'No name alias set'}</p>
        <h6>Status</h6>
        <p>
          <DeviceStatus status={device.deviceStatus} />
        </p>
        <h6>Credentials inhibited</h6>
        <p>{device.hasCredentialsInhibited ? 'True' : 'False'}</p>
        <div className="mt-auto d-flex flex-column flex-md-row flex-wrap gap-2">
          {device.hasCredentialsInhibited ? (
            <Button
              variant="success text-white"
              onClick={onEnableCredentialsClick}
              disabled={device.deletionInProgress}
              hidden={!astarte.token?.can('appEngine', 'PATCH', `/devices/${device.id}`)}
            >
              Enable credentials request
            </Button>
          ) : (
            <Button
              variant="danger"
              onClick={onInhibitCredentialsClick}
              disabled={device.deletionInProgress}
              hidden={!astarte.token?.can('appEngine', 'PATCH', `/devices/${device.id}`)}
            >
              Inhibit credentials
            </Button>
          )}
          <Button
            variant="danger"
            onClick={onWipeCredentialsClick}
            hidden={!astarte.token?.can('pairing', 'DELETE', `/agent/devices/${device.id}`)}
            disabled={device.deletionInProgress}
          >
            Wipe credential secret
          </Button>
          <Button
            variant="danger"
            onClick={onDeleteDeviceClick}
            hidden={!astarte.token?.can('realmManagement', 'DELETE', `/devices/${device.id}`)}
            disabled={device.deletionInProgress}
          >
            Delete device
          </Button>
        </div>
      </Card.Body>
    </FullHeightCard>
  );
};

export default DeviceInfoCard;
