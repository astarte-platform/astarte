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

import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Button, Spinner, Table } from 'react-bootstrap';

import SingleCardPage from './ui/SingleCardPage';
import { useAlerts } from './AlertManager';

export default ({ astarte, history }) => {
  const [phase, setPhase] = useState('loading');
  const [groups, setGroups] = useState(null);
  const pageAlerts = useAlerts();

  useEffect(() => {
    const handleDeviceList = (groupName, devices) => {
      setGroups((groupMap) => {
        const newGroupState = groupMap.get(groupName);
        newGroupState.loading = false;
        newGroupState.totalDevices = devices.length;
        const connectedDevices = devices.filter((device) => device.isConnected);
        newGroupState.connectedDevices = connectedDevices.length;
        groupMap.set(groupName, newGroupState);
        return new Map(groupMap);
      });
    };
    const handleGroupsRequest = (groupNames) => {
      const groupMap = groupNames.reduce((acc, groupName) => {
        acc.set(groupName, { name: groupName, loading: true });
        return acc;
      }, new Map());
      groupMap.forEach((value, groupName) => {
        astarte
          .getDevicesInGroup({
            groupName,
            details: true,
          })
          .then((devices) => handleDeviceList(groupName, devices))
          .catch(() => {
            pageAlerts.showError(`Couldn't get the device list for group ${groupName}`);
          });
      });
      setGroups(groupMap);
      setPhase('ok');
    };
    const handleGroupsError = () => {
      setPhase('err');
    };
    astarte.getGroupList().then(handleGroupsRequest).catch(handleGroupsError);
  }, [astarte, setGroups, setPhase]);

  let innerHTML;

  switch (phase) {
    case 'ok':
      if (groups.size === 0) {
        innerHTML = <p>No registered group</p>;
      } else {
        innerHTML = (
          <Table responsive>
            <thead>
              <tr>
                <th>Group name</th>
                <th>Connected devices</th>
                <th>Total devices</th>
              </tr>
            </thead>
            <tbody>
              {Array.from(groups.values()).map((group) => {
                const encodedGroupName = encodeURIComponent(encodeURIComponent(group.name));
                return (
                  <tr key={group.name}>
                    <td>
                      <Link to={`/groups/${encodedGroupName}/`}>{group.name}</Link>
                    </td>
                    <td>{group.connectedDevices}</td>
                    <td>{group.totalDevices}</td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        );
      }
      break;

    case 'err':
      innerHTML = <p>Couldn&apos;t load groups</p>;
      break;

    default:
      innerHTML = (
        <div>
          <Spinner animation="border" role="status" />
        </div>
      );
      break;
  }

  return (
    <SingleCardPage title="Groups">
      <pageAlerts.Alerts />
      {innerHTML}
      <Button
        variant="primary"
        onClick={() => {
          history.push('/groups/new');
        }}
      >
        Create new group
      </Button>
    </SingleCardPage>
  );
};
