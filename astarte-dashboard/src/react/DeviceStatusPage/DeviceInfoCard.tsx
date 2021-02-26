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

interface ConnectionStatusProps {
  status: AstarteDevice['connectionStatus'];
}

const ConnectionStatus = ({ status }: ConnectionStatusProps): React.ReactElement => {
  let statusString;
  let icon;

  switch (status) {
    case 'connected':
      statusString = 'Connected';
      icon = 'icon-connected';
      break;

    case 'disconnected':
      statusString = 'Disconnected';
      icon = 'icon-disconnected';
      break;

    case 'never_connected':
    default:
      statusString = 'Never connected';
      icon = 'icon-never-connected';
      break;
  }

  return (
    <>
      <i className={['fas fa-circle mr-1', icon].join(' ')} />
      <span>{statusString}</span>
    </>
  );
};

interface DeviceInfoCardProps {
  device: AstarteDevice;
  onInhibitCredentialsClick: () => void;
  onEnableCredentialsClick: () => void;
  onWipeCredentialsClick: () => void;
}

const DeviceInfoCard = ({
  device,
  onInhibitCredentialsClick,
  onEnableCredentialsClick,
  onWipeCredentialsClick,
}: DeviceInfoCardProps): React.ReactElement => (
  <FullHeightCard xs={12} md={6} className="mb-4">
    <Card.Header as="h5">Device Info</Card.Header>
    <Card.Body className="d-flex flex-column">
      <h6>Device ID</h6>
      <p className="text-monospace">{device.id}</p>
      <h6>Device name</h6>
      <p>{device.hasNameAlias ? device.name : 'No name alias set'}</p>
      <h6>Status</h6>
      <p>
        <ConnectionStatus status={device.connectionStatus} />
      </p>
      <h6>Credentials inhibited</h6>
      <p>{device.hasCredentialsInhibited ? 'True' : 'False'}</p>
      <div className="mt-auto">
        {device.hasCredentialsInhibited ? (
          <Button variant="success text-white" className="mr-1" onClick={onEnableCredentialsClick}>
            Enable credentials request
          </Button>
        ) : (
          <Button variant="danger" className="mr-1" onClick={onInhibitCredentialsClick}>
            Inhibit credentials
          </Button>
        )}
        <Button variant="danger" onClick={onWipeCredentialsClick}>
          Wipe credential secret
        </Button>
      </div>
    </Card.Body>
  </FullHeightCard>
);

export default DeviceInfoCard;
