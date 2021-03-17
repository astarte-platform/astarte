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
import { Card } from 'react-bootstrap';

import type { AstarteDevice } from 'astarte-client';
import FullHeightCard from '../components/FullHeightCard';

interface DeviceStatusEventsCardProps {
  device: AstarteDevice;
}

const DeviceStatusEventsCard = ({ device }: DeviceStatusEventsCardProps): React.ReactElement => {
  const propertyArray = [
    { label: 'Last seen IP', value: device.lastSeenIp },
    { label: 'Last credentials request IP', value: device.lastCredentialsRequestIp },
    { label: 'First credentials request', value: device.firstCredentialsRequest?.toLocaleString() },
    { label: 'First registration', value: device.firstRegistration?.toLocaleString() },
    { label: 'Last connection', value: device.lastConnection?.toLocaleString() },
    { label: 'Last disconnection', value: device.lastDisconnection?.toLocaleString() },
  ].filter(({ value }) => value !== undefined);

  return (
    <FullHeightCard xs={12} className="mb-4">
      <Card.Header as="h5">Device Status Events</Card.Header>
      <Card.Body className="d-flex flex-column">
        {propertyArray.map(({ label, value }) => (
          <React.Fragment key={label}>
            <h6>{label}</h6>
            <p>{value}</p>
          </React.Fragment>
        ))}
      </Card.Body>
    </FullHeightCard>
  );
};

export default DeviceStatusEventsCard;
