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

import _ from 'lodash';
import * as yup from 'yup';

import { AstarteDeviceEvent, AstarteDeviceEventDTO } from './AstarteDeviceEvent';

type AstarteDeviceConnectedEventDTO = AstarteDeviceEventDTO & {
  event: {
    type: 'device_connected';
    // eslint-disable-next-line camelcase
    device_ip_address: string;
  };
};

const validationSchema: yup.ObjectSchema<AstarteDeviceConnectedEventDTO['event']> = yup
  .object({
    type: yup.string().oneOf(['device_connected']).required(),
    device_ip_address: yup.string().required(),
  })
  .required();

export class AstarteDeviceConnectedEvent extends AstarteDeviceEvent {
  readonly ip: string;

  private constructor(arg: unknown) {
    super(arg);
    const event = validationSchema.validateSync(_.get(arg, 'event'));
    this.ip = event.device_ip_address;
  }

  static fromJSON(arg: unknown): AstarteDeviceConnectedEvent {
    return new AstarteDeviceConnectedEvent(arg);
  }
}
