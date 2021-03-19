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
import { Card, Table } from 'react-bootstrap';

import type { AstarteDevice, AstarteDeviceInterfaceStats } from 'astarte-client';
import FullHeightCard from '../components/FullHeightCard';

interface PreviousInterfacesTable {
  interfaces: AstarteDeviceInterfaceStats[];
}

const PreviousInterfacesTable = ({ interfaces }: PreviousInterfacesTable): React.ReactElement => (
  <Table responsive>
    <thead>
      <tr>
        <th>Name</th>
        <th>Major</th>
        <th>Minor</th>
      </tr>
    </thead>
    <tbody>
      {interfaces.map((iface) => (
        <tr key={`${iface.name} v${iface.major}`}>
          <td>{iface.name}</td>
          <td>{iface.major}</td>
          <td>{iface.minor}</td>
        </tr>
      ))}
    </tbody>
  </Table>
);

interface PreviousInterfacesCardProps {
  device: AstarteDevice;
}

const PreviousInterfacesCard = ({ device }: PreviousInterfacesCardProps): React.ReactElement => (
  <FullHeightCard className="mb-4">
    <Card.Header as="h5">Previous Interfaces</Card.Header>
    <Card.Body className="d-flex flex-column">
      {device.previousInterfaces.length > 0 ? (
        <PreviousInterfacesTable interfaces={device.previousInterfaces} />
      ) : (
        <p>No previous interfaces info</p>
      )}
    </Card.Body>
  </FullHeightCard>
);

export default PreviousInterfacesCard;
