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

import AstarteClient from 'astarte-client';
import type { AstarteDatastreamObjectData } from 'astarte-client';

import { ChartProvider } from './provider';
import { TimestampedAggregated } from '../dataKinds';

interface ProviderParams {
  name?: string;
  deviceId: string;
  interfaceName: string;
  endpoint: string;
}

const generateDeviceDatastreamObjectProvider = (
  client: AstarteClient,
  params: ProviderParams,
): ChartProvider<'Array', TimestampedAggregated> =>
  new ChartProvider({
    name: params.name || params.deviceId,
    dataWrapper: 'Array',
    dataKind: TimestampedAggregated,
    async getData(): Promise<TimestampedAggregated[]> {
      const dataTree = await client.getDeviceDataTree({
        deviceId: params.deviceId,
        interfaceName: params.interfaceName,
      });
      if (dataTree.dataKind !== 'datastream_object') {
        return [];
      }
      const deviceValues = dataTree.toData() as AstarteDatastreamObjectData[];
      const filteredDeviceValues = deviceValues.filter(
        (deviceValue) => deviceValue.endpoint === params.endpoint,
      );
      return filteredDeviceValues.map((deviceValue) => ({
        data: deviceValue.value,
        timestamp: deviceValue.timestamp,
      }));
    },
  });

export { generateDeviceDatastreamObjectProvider };
