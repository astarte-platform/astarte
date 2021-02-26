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

interface AliasKeyValuePair {
  key: string;
  value: string;
}

interface AliasesTableProps {
  aliases: Map<string, string>;
  onEditAliasClick: (key: string) => void;
  onRemoveAliasClick: ({ key, value }: AliasKeyValuePair) => void;
}

const AliasesTable = ({
  aliases,
  onEditAliasClick,
  onRemoveAliasClick,
}: AliasesTableProps): React.ReactElement => (
  <Table responsive>
    <thead>
      <tr>
        <th>Tag</th>
        <th>Alias</th>
        <th className="action-column">Actions</th>
      </tr>
    </thead>
    <tbody>
      {Array.from(aliases.entries()).map(([key, value]) => (
        <tr key={key}>
          <td>{key}</td>
          <td>{value}</td>
          <td className="text-center">
            <i
              className="fas fa-pencil-alt color-grey action-icon mr-2"
              onClick={() => onEditAliasClick(key)}
            />
            <i
              className="fas fa-eraser color-red action-icon"
              onClick={() => onRemoveAliasClick({ key, value })}
            />
          </td>
        </tr>
      ))}
    </tbody>
  </Table>
);

interface AliasesCardProps {
  device: AstarteDevice;
  onNewAliasClick: () => void;
  onEditAliasClick: (key: string) => void;
  onRemoveAliasClick: ({ key, value }: AliasKeyValuePair) => void;
}

const AliasesCard = ({
  device,
  onNewAliasClick,
  onEditAliasClick,
  onRemoveAliasClick,
}: AliasesCardProps): React.ReactElement => (
  <FullHeightCard xs={12} md={6} className="mb-4">
    <Card.Header as="h5">Aliases</Card.Header>
    <Card.Body className="d-flex flex-column">
      {device.aliases.size > 0 ? (
        <AliasesTable
          aliases={device.aliases}
          onEditAliasClick={onEditAliasClick}
          onRemoveAliasClick={onRemoveAliasClick}
        />
      ) : (
        <p>Device has no aliases</p>
      )}
      <div className="mt-auto">
        <Button variant="primary" onClick={onNewAliasClick}>
          Add new alias
        </Button>
      </div>
    </Card.Body>
  </FullHeightCard>
);

export default AliasesCard;
