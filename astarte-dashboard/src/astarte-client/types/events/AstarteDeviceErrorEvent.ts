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

const deviceErrorNames = [
  'write_on_server_owned_interface',
  'invalid_interface',
  'invalid_path',
  'mapping_not_found',
  'interface_loading_failed',
  'ambiguous_path',
  'undecodable_bson_payload',
  'unexpected_value_type',
  'value_size_exceeded',
  'unexpected_object_key',
  'invalid_introspection',
  'unexpected_control_message',
  'device_session_not_found',
  'resend_interface_properties_failed',
  'empty_cache_error',
] as const;

type DeviceErrorName = typeof deviceErrorNames[number];

type AstarteDeviceErrorEventDTO = AstarteDeviceEventDTO & {
  event: {
    type: 'device_error';
    // eslint-disable-next-line camelcase
    error_name: DeviceErrorName;
    metadata: Record<string, string> | null | undefined;
  };
};

const validationSchema: yup.ObjectSchema<AstarteDeviceErrorEventDTO['event']> = yup
  .object({
    type: yup.string().oneOf(['device_error']).required(),
    error_name: yup.string().oneOf(deviceErrorNames).required(),
    metadata: yup.object(),
  })
  .required();

export class AstarteDeviceErrorEvent extends AstarteDeviceEvent {
  readonly errorName: DeviceErrorName;

  readonly metadata: Record<string, string> | null | undefined;

  private constructor(arg: unknown) {
    super(arg);
    const event = validationSchema.validateSync(_.get(arg, 'event'));
    this.errorName = event.error_name;
    this.metadata = event.metadata;
  }

  static fromJSON(arg: unknown): AstarteDeviceErrorEvent {
    return new AstarteDeviceErrorEvent(arg);
  }
}
