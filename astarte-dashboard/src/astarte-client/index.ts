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

import AstarteClient from './client';

export type { AstarteInterfaceDescriptor } from './client';

export {
  AstarteCustomBlock,
  AstarteNativeBlock,
  AstarteDevice,
  AstarteFlow,
  AstartePipeline,
  AstarteInterface,
  AstarteMapping,
  AstarteRealm,
  AstarteToken,
  AstarteTrigger,
} from './models';

export type {
  AstarteTriggerHTTPAction,
  AstarteTriggerAMQPAction,
  AstarteSimpleDeviceTrigger,
  AstarteSimpleDataTrigger,
  AstarteSimpleTrigger,
} from './models';

export {
  AstarteDeviceEvent,
  AstarteDeviceConnectedEvent,
  AstarteDeviceDisconnectedEvent,
  AstarteDeviceErrorEvent,
  AstarteDeviceIncomingDataEvent,
  AstarteDeviceUnsetPropertyEvent,
} from './types/events';

export type { AstarteBlock, AstarteDeviceInterfaceStats } from './models';

export type { AstarteDataTreeNode, AstarteDataTreeKind } from './transforms';

export type {
  AstarteDataType,
  AstarteDataTuple,
  AstarteDataValue,
  AstartePropertyData,
  AstarteDatastreamData,
  AstarteDatastreamIndividualData,
  AstarteDatastreamObjectData,
  AstartePropertiesInterfaceValues,
  AstarteIndividualDatastreamInterfaceValue,
  AstarteIndividualDatastreamInterfaceValues,
  AstarteAggregatedDatastreamInterfaceValue,
  AstarteAggregatedDatastreamInterfaceValues,
  AstarteInterfaceValues,
} from './types';

export default AstarteClient;
