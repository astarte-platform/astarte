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
import type { AstartePropertyData, AstarteDataTuple } from 'astarte-client';

import { ChartProvider } from './provider';
import { Aggregated } from '../dataKinds';

interface ProviderParams {
  name?: string;
  deviceId: string;
  interfaceName: string;
  endpoint: string;
}

const generateDevicePropertyProvider = (
  client: AstarteClient,
  params: ProviderParams,
): ChartProvider<'Object', Aggregated> =>
  new ChartProvider({
    name: params.name || params.deviceId,
    dataWrapper: 'Object',
    dataKind: Aggregated,
    async getData(): Promise<Aggregated> {
      const dataTree = await client.getDeviceDataTree({
        deviceId: params.deviceId,
        interfaceName: params.interfaceName,
      });
      if (dataTree.dataKind !== 'properties') {
        return {
          data: {},
        };
      }
      const deviceValues = dataTree.toLinearizedData() as AstartePropertyData[];
      const property = deviceValues.find((deviceValue) => deviceValue.endpoint === params.endpoint);
      if (!property) {
        return {
          data: {},
        };
      }
      const endpointLastPart = property.endpoint.split('/').pop() || '';
      return {
        data: {
          [endpointLastPart]: {
            value: property.value,
            type: property.type,
          } as AstarteDataTuple,
        },
      };
    },
  });

export { generateDevicePropertyProvider };
