/* eslint-disable camelcase */
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

export class AstarteDeviceUnsetPropertyEvent extends AstarteDeviceEvent {
  readonly interfaceName: string;

  readonly path: string;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private constructor(arg: any) {
    super(arg);
    if (
      !arg.event ||
      !_.isPlainObject(arg.event) ||
      arg.event.type !== 'incoming_data' ||
      arg.event.value !== null
    ) {
      throw new Error('Invalid event');
    }
    if (typeof arg.event.interface !== 'string') {
      throw new Error('Invalid interface');
    }
    if (typeof arg.event.path !== 'string') {
      throw new Error('Invalid path');
    }
    if (arg.event.value) {
      throw new Error('Invalid sent value');
    }

    this.interfaceName = arg.event.interface;
    this.path = arg.event.path;
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  static fromJSON(arg: any): AstarteDeviceUnsetPropertyEvent {
    return new AstarteDeviceUnsetPropertyEvent(arg);
  }
}
