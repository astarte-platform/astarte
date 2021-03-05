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

import React, { useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button, Container, Spinner, Table } from 'react-bootstrap';

import SingleCardPage from './ui/SingleCardPage';
import { useAlerts } from './AlertManager';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import { useAstarte } from './AstarteManager';

interface GroupState {
  name: string;
  totalDevices: number;
  connectedDevices: number;
}

type GroupMap = Map<string, GroupState>;

type GroupsTableProps = {
  groupMap: GroupMap;
};

const GroupsTable = ({ groupMap }: GroupsTableProps) => {
  if (groupMap.size === 0) {
    return <p>No registered group</p>;
  }
  return (
    <Table responsive>
      <thead>
        <tr>
          <th>Group name</th>
          <th>Connected devices</th>
          <th>Total devices</th>
        </tr>
      </thead>
      <tbody>
        {Array.from(groupMap.values()).map((group) => {
          const encodedGroupName = encodeURIComponent(encodeURIComponent(group.name));
          return (
            <tr key={group.name}>
              <td>
                <Link to={`/groups/${encodedGroupName}/edit`}>{group.name}</Link>
              </td>
              <td>{group.connectedDevices}</td>
              <td>{group.totalDevices}</td>
            </tr>
          );
        })}
      </tbody>
    </Table>
  );
};

export default (): React.ReactElement => {
  const astarte = useAstarte();
  const pageAlerts = useAlerts();
  const navigate = useNavigate();

  const fetchGroups = useCallback(async (): Promise<GroupMap> => {
    pageAlerts.closeAll();
    const groupNames = await astarte.client.getGroupList();
    const groupMap: GroupMap = new Map();
    const fetchGroupPromises = groupNames.map((groupName) =>
      astarte.client
        .getDevicesInGroup({
          groupName,
          details: true,
        })
        .catch(() => {
          pageAlerts.showError(`Couldn't get the device list for group ${groupName}`);
          return null;
        }),
    );
    const groupsDevices = await Promise.all(fetchGroupPromises);
    groupNames.forEach((groupName, index) => {
      const groupDevices = groupsDevices[index];
      if (groupDevices) {
        groupMap.set(groupName, {
          name: groupName,
          totalDevices: groupDevices.length,
          connectedDevices: groupDevices.filter((device) => device.isConnected).length,
        });
      }
    });
    return groupMap;
  }, [astarte.client, pageAlerts.closeAll, pageAlerts.showError]);

  const groupsFetcher = useFetch(fetchGroups);

  return (
    <SingleCardPage title="Groups">
      <pageAlerts.Alerts />
      <WaitForData
        data={groupsFetcher.value}
        status={groupsFetcher.status}
        fallback={
          <Container fluid className="text-center">
            <Spinner animation="border" role="status" />
          </Container>
        }
        errorFallback={<Empty title="Couldn't load groups" onRetry={groupsFetcher.refresh} />}
      >
        {(groupMap) => <GroupsTable groupMap={groupMap} />}
      </WaitForData>
      <Button
        variant="primary"
        onClick={() => {
          navigate('/groups/new');
        }}
      >
        Create new group
      </Button>
    </SingleCardPage>
  );
};
