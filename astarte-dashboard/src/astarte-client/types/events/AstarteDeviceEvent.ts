/* eslint-disable camelcase */
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

import * as yup from 'yup';

type AstarteDeviceEventDTO = {
  device_id: string;
  timestamp: string;
  event: Record<string, unknown>;
};

const astarteDeviceEventSchema: yup.ObjectSchema<AstarteDeviceEventDTO> = yup
  .object({
    device_id: yup.string().required(),
    timestamp: yup.string().required(),
    event: yup.object(),
  })
  .required();

export abstract class AstarteDeviceEvent {
  readonly deviceId: string;

  readonly timestamp: Date;

  protected constructor(arg: unknown) {
    const event = astarteDeviceEventSchema.validateSync(arg);

    const timestamp = new Date(event.timestamp);
    if (Number.isNaN(timestamp.getTime())) {
      throw new Error('Invalid timestamp');
    }

    this.deviceId = event.device_id;
    this.timestamp = timestamp;
  }
}

export type { AstarteDeviceEventDTO };
