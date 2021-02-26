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
import { Link } from 'react-router-dom';

import type { AstarteDevice } from 'astarte-client';
import FullHeightCard from '../components/FullHeightCard';

interface GroupsTableProps {
  groups: string[];
}

const GroupsTable = ({ groups }: GroupsTableProps): React.ReactElement => (
  <Table responsive>
    <thead>
      <tr>
        <th>Name</th>
      </tr>
    </thead>
    <tbody>
      {groups.map((groupName, index) => {
        const encodedGroupName = encodeURIComponent(encodeURIComponent(groupName));
        return (
          <tr key={index}>
            <td>
              <Link to={`/groups/${encodedGroupName}/edit`}>{groupName}</Link>
            </td>
          </tr>
        );
      })}
    </tbody>
  </Table>
);

interface GroupsCardProps {
  device: AstarteDevice;
  showAddToGropButton: boolean;
  onAddToGroupClick: () => void;
}

const GroupsCard = ({
  device,
  showAddToGropButton,
  onAddToGroupClick,
}: GroupsCardProps): React.ReactElement => (
  <FullHeightCard xs={12} md={6} className="mb-4">
    <Card.Header as="h5">Groups</Card.Header>
    <Card.Body className="d-flex flex-column">
      {device.groups.length > 0 ? (
        <GroupsTable groups={device.groups} />
      ) : (
        <p>Device does not belong to any group</p>
      )}
      <div className="mt-auto">
        {showAddToGropButton && (
          <Button variant="primary" onClick={onAddToGroupClick}>
            Add to existing group
          </Button>
        )}
      </div>
    </Card.Body>
  </FullHeightCard>
);

export default GroupsCard;
