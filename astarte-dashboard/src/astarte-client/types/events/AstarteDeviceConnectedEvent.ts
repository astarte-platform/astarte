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

import _ from 'lodash';
import { AstarteDeviceEvent } from './AstarteDeviceEvent';

export class AstarteDeviceConnectedEvent extends AstarteDeviceEvent {
  readonly ip: string;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private constructor(arg: any) {
    super(arg);
    if (!arg.event || !_.isPlainObject(arg.event) || arg.event.type !== 'device_connected') {
      throw new Error('Invalid event');
    }
    if (typeof arg.event.device_ip_address !== 'string') {
      throw new Error('Invalid device ip address');
    }
    this.ip = arg.event.device_ip_address;
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  static fromJSON(arg: any): AstarteDeviceConnectedEvent {
    return new AstarteDeviceConnectedEvent(arg);
  }
}
