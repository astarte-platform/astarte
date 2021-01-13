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

import { ChartProvider } from './provider';
import { ConnectedDevices } from '../dataKinds';

interface ProviderParams {
  name?: string;
}

const generateConnectedDevicesProvider = (
  client: AstarteClient,
  params: ProviderParams = {},
): ChartProvider<'Object', ConnectedDevices> =>
  new ChartProvider({
    name: params.name || 'Connected devices',
    dataWrapper: 'Object',
    dataKind: ConnectedDevices,
    async getData(): Promise<ConnectedDevices> {
      const devicesStats = await client.getDevicesStats();
      return {
        data: {
          connected: {
            value: Number(devicesStats.connected_devices),
            type: 'integer',
          },
          disconnected: {
            value: Number(devicesStats.total_devices - devicesStats.connected_devices),
            type: 'integer',
          },
        },
      };
    },
  });

export { generateConnectedDevicesProvider };
