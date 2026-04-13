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
import type { AstarteDataValue } from '../dataType';

type AstarteDeviceIncomingDataDTO = AstarteDeviceEventDTO & {
  event: {
    type: 'incoming_data';
    interface: string;
    path: string;
    value: AstarteDataValue | Record<string, AstarteDataValue>;
  };
};

const validationSchema: yup.ObjectSchema<AstarteDeviceIncomingDataDTO['event']> = yup
  .object({
    type: yup.string().oneOf(['incoming_data']).required(),
    interface: yup.string().required(),
    path: yup.string().required(),
    value: yup.mixed().required(),
  })
  .required();

export class AstarteDeviceIncomingDataEvent extends AstarteDeviceEvent {
  readonly interfaceName: string;

  readonly path: string;

  readonly value: AstarteDataValue | Record<string, AstarteDataValue>;

  private constructor(arg: unknown) {
    super(arg);
    const event = validationSchema.validateSync(_.get(arg, 'event'));
    this.interfaceName = event.interface;
    this.path = event.path;
    this.value = event.value;
  }

  static fromJSON(arg: unknown): AstarteDeviceIncomingDataEvent {
    return new AstarteDeviceIncomingDataEvent(arg);
  }
}
