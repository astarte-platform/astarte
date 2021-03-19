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
import { Link } from 'react-router-dom';

import type { AstarteDevice, AstarteDeviceInterfaceStats } from 'astarte-client';
import FullHeightCard from '../components/FullHeightCard';

interface IntrospectionTableProps {
  deviceId: string;
  introspection: AstarteDeviceInterfaceStats[];
}

const IntrospectionTable = ({
  deviceId,
  introspection,
}: IntrospectionTableProps): React.ReactElement => (
  <Table responsive>
    <thead>
      <tr>
        <th>Name</th>
        <th>Major</th>
        <th>Minor</th>
      </tr>
    </thead>
    <tbody>
      {introspection.map((iface) => (
        <tr key={iface.name}>
          <td>
            <Link to={`/devices/${deviceId}/interfaces/${iface.name}`}>{iface.name}</Link>
          </td>
          <td>{iface.major}</td>
          <td>{iface.minor}</td>
        </tr>
      ))}
    </tbody>
  </Table>
);

interface IntrospectionCardProps {
  device: AstarteDevice;
}

const IntrospectionCard = ({ device }: IntrospectionCardProps): React.ReactElement => {
  const introspection = Array.from(device.introspection.values());

  return (
    <FullHeightCard xs={12} md={6} className="mb-4">
      <Card.Header as="h5">Interfaces</Card.Header>
      <Card.Body className="d-flex flex-column">
        {introspection.length > 0 ? (
          <IntrospectionTable deviceId={device.id} introspection={introspection} />
        ) : (
          <p>No introspection info</p>
        )}
      </Card.Body>
    </FullHeightCard>
  );
};

export default IntrospectionCard;
