/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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

import type AstarteClient from 'astarte-client';
import _ from 'lodash';

import { ChartProvider } from './provider';
import { DeviceStats } from '../dataKinds';

interface ProviderParams {
  name?: string;
  deviceId: string;
  stats?: 'exchangedBytes' | 'exchangedMessages';
}

const generateDeviceStatsProvider = (
  client: AstarteClient,
  params: ProviderParams,
): ChartProvider<'Object', DeviceStats> =>
  new ChartProvider({
    name: params.name || 'Device stats',
    dataWrapper: 'Object',
    dataKind: DeviceStats,
    async getData(): Promise<DeviceStats> {
      const device = await client.getDeviceInfo(params.deviceId);
      const currentInterfaces = Array.from(device.introspection.values());
      const interfaces = [...currentInterfaces, ...device.previousInterfaces];
      const totalBytes = device.totalReceivedBytes;
      const totalMessages = device.totalReceivedMessages;
      const interfacesBytes = _.sumBy(interfaces, 'exchangedBytes');
      const interfacesMessages = _.sumBy(interfaces, 'exchangedMessages');
      const otherBytes = totalBytes - interfacesBytes;
      const otherMessages = totalMessages - interfacesMessages;
      return {
        data: interfaces.reduce(
          (acc, iface) => ({
            ...acc,
            [`${iface.name} v${iface.major}.${iface.minor}`]: {
              type: 'integer',
              value: Number(
                (params.stats === 'exchangedMessages'
                  ? iface.exchangedMessages
                  : iface.exchangedBytes) || 0,
              ),
            },
          }),
          {
            Other: {
              type: 'integer',
              value: Number(params.stats === 'exchangedMessages' ? otherMessages : otherBytes),
            },
          },
        ),
      };
    },
  });

export { generateDeviceStatsProvider };
