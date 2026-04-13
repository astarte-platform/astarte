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

type AstarteDeviceDisconnectedEventDTO = AstarteDeviceEventDTO & {
  event: {
    type: 'device_disconnected';
  };
};

const validationSchema: yup.ObjectSchema<AstarteDeviceDisconnectedEventDTO['event']> = yup
  .object({
    type: yup.string().oneOf(['device_disconnected']).required(),
  })
  .required();

export class AstarteDeviceDisconnectedEvent extends AstarteDeviceEvent {
  private constructor(arg: unknown) {
    super(arg);
    validationSchema.validateSync(_.get(arg, 'event'));
  }

  static fromJSON(arg: unknown): AstarteDeviceDisconnectedEvent {
    return new AstarteDeviceDisconnectedEvent(arg);
  }
}
