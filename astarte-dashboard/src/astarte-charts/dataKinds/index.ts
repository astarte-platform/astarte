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

import { Aggregated } from './Aggregated';
import { TimestampedAggregated } from './TimestampedAggregated';
import { TimestampedIndividual } from './TimestampedIndividual';
import { ConnectedDevices } from './ConnectedDevices';
import { DeviceStats } from './DeviceStats';

type ChartDataKind =
  | Aggregated
  | TimestampedAggregated
  | TimestampedIndividual
  | ConnectedDevices
  | DeviceStats;

type ChartDataWrapper = 'Object' | 'Array';

type ChartData<
  Wrapper extends ChartDataWrapper,
  Kind extends ChartDataKind,
> = Wrapper extends 'Object' ? Kind : Wrapper extends 'Array' ? Kind[] : never;

export { Aggregated, TimestampedAggregated, TimestampedIndividual, ConnectedDevices, DeviceStats };

export type { ChartData, ChartDataKind, ChartDataWrapper };
