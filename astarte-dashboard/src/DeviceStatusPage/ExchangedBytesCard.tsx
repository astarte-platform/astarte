/*
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl

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

import React, { useMemo } from 'react';
import { Card, Col, Row, Table } from 'react-bootstrap';
import AstarteClient, { AstarteDevice, AstarteDeviceInterfaceStats } from 'astarte-client';
import { getDeviceStats } from 'astarte-charts';
import { PieChart } from 'astarte-charts/react';

import FullHeightCard from '../components/FullHeightCard';

const formatBytes = (bytes: number): string => {
  if (bytes < 1024) {
    return `${bytes}B`;
  }
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(2)}KiB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(2)}MiB`;
};

type BytesAndMessagesStats = {
  name: string;
  bytes: number;
  bytesPercent: number;
  messages: number;
  messagesPercent: number;
};

interface StatsTableRowProps {
  stats: BytesAndMessagesStats;
}

const StatsTableRow = ({ stats }: StatsTableRowProps): React.ReactElement => (
  <tr>
    <td>{stats.name}</td>
    <td className="text-right">{formatBytes(stats.bytes)}</td>
    <td className="d-xl-table-cell d-none text-right">{`${stats.bytesPercent.toFixed(2)}%`}</td>
    <td className="text-right">{stats.messages}</td>
    <td className="d-xl-table-cell d-none text-right">{`${stats.messagesPercent.toFixed(2)}%`}</td>
  </tr>
);

interface ExchangedBytesCardProps {
  astarte: AstarteClient;
  device: AstarteDevice;
}

const ExchangedBytesCard = ({ astarte, device }: ExchangedBytesCardProps): React.ReactElement => {
  const deviceStatsProvider = useMemo(
    () => getDeviceStats(astarte, { deviceId: device.id, stats: 'exchangedBytes' }),
    [astarte],
  );
  const fullList = Array.from(device.introspection.values()).concat(device.previousInterfaces);
  const totalBytes = device.totalReceivedBytes;
  const totalMessages = device.totalReceivedMessages;

  const computedStats: BytesAndMessagesStats[] = [];
  let interfaceBytes = 0;
  let interfaceMessages = 0;
  fullList.forEach((interfaceStats: AstarteDeviceInterfaceStats) => {
    interfaceBytes += interfaceStats.exchangedBytes;
    interfaceMessages += interfaceStats.exchangedMessages;
    computedStats.push({
      name: `${interfaceStats.name} v${interfaceStats.major}.${interfaceStats.minor}`,
      bytes: interfaceStats.exchangedBytes,
      bytesPercent: (interfaceStats.exchangedBytes * 100) / totalBytes,
      messages: interfaceStats.exchangedMessages,
      messagesPercent: (interfaceStats.exchangedMessages * 100) / totalMessages,
    });
  });

  computedStats.push({
    name: 'Other',
    bytes: totalBytes - interfaceBytes,
    bytesPercent: ((totalBytes - interfaceBytes) * 100) / totalBytes,
    messages: totalMessages - interfaceMessages,
    messagesPercent: ((totalMessages - interfaceMessages) * 100) / totalMessages,
  });

  computedStats.push({
    name: 'Total',
    bytes: totalBytes,
    bytesPercent: 100,
    messages: totalMessages,
    messagesPercent: 100,
  });

  return (
    <FullHeightCard xs={12} className="mb-4">
      <Card.Header as="h5">Device Stats</Card.Header>
      <Card.Body className="d-flex flex-column">
        <Row className="mt-3">
          <Col>
            <Table responsive>
              <thead>
                <tr>
                  <th>Interface</th>
                  <th className="text-right">Bytes</th>
                  <th className="d-xl-table-cell d-none text-right">Bytes (%)</th>
                  <th className="text-right">Messages</th>
                  <th className="d-xl-table-cell d-none text-right">Messages (%)</th>
                </tr>
              </thead>
              <tbody>
                {computedStats.map((stats) => (
                  <StatsTableRow key={stats.name} stats={stats} />
                ))}
              </tbody>
            </Table>
          </Col>
          <Col sm={12} xl={4}>
            <PieChart providers={[deviceStatsProvider]} />
          </Col>
        </Row>
      </Card.Body>
    </FullHeightCard>
  );
};

export default ExchangedBytesCard;
