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
import { Button, Card, Table } from 'react-bootstrap';

import type { AstarteDevice } from 'astarte-client';
import FullHeightCard from '../components/FullHeightCard';

interface MetadataKeyValuePair {
  key: string;
  value: string;
}

interface MetadataTableProps {
  metadata: Map<string, string>;
  onEditMetadataClick: (key: string) => void;
  onRemoveMetadataClick: ({ key, value }: MetadataKeyValuePair) => void;
}

const MetadataTable = ({
  metadata,
  onEditMetadataClick,
  onRemoveMetadataClick,
}: MetadataTableProps): React.ReactElement => (
  <Table responsive>
    <thead>
      <tr>
        <th>Field</th>
        <th>Value</th>
        <th className="action-column">Actions</th>
      </tr>
    </thead>
    <tbody>
      {Array.from(metadata.entries()).map(([key, value]) => (
        <tr key={key}>
          <td>{key}</td>
          <td>{value}</td>
          <td className="text-center">
            <i
              className="fas fa-pencil-alt color-grey action-icon mr-2"
              onClick={() => onEditMetadataClick(key)}
            />
            <i
              className="fas fa-eraser color-red action-icon"
              onClick={() => onRemoveMetadataClick({ key, value })}
            />
          </td>
        </tr>
      ))}
    </tbody>
  </Table>
);

interface MetadataCardProps {
  device: AstarteDevice;
  onNewMetadataClick: () => void;
  onEditMetadataClick: (key: string) => void;
  onRemoveMetadataClick: ({ key, value }: MetadataKeyValuePair) => void;
}

const MetadataCard = ({
  device,
  onNewMetadataClick,
  onEditMetadataClick,
  onRemoveMetadataClick,
}: MetadataCardProps): React.ReactElement => (
  <FullHeightCard xs={12} md={6} className="mb-4">
    <Card.Header as="h5">Metadata</Card.Header>
    <Card.Body className="d-flex flex-column">
      {device.metadata.size > 0 ? (
        <MetadataTable
          metadata={device.metadata}
          onEditMetadataClick={onEditMetadataClick}
          onRemoveMetadataClick={onRemoveMetadataClick}
        />
      ) : (
        <p>Device has no metadata</p>
      )}
      <div className="mt-auto">
        <Button variant="primary" onClick={onNewMetadataClick}>
          Add new item
        </Button>
      </div>
    </Card.Body>
  </FullHeightCard>
);

export default MetadataCard;
