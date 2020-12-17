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

type DeviceErrorName =
  | 'write_on_server_owned_interface'
  | 'invalid_interface'
  | 'invalid_path'
  | 'mapping_not_found'
  | 'interface_loading_failed'
  | 'ambiguous_path'
  | 'undecodable_bson_payload'
  | 'unexpected_value_type'
  | 'value_size_exceeded'
  | 'unexpected_object_key'
  | 'invalid_introspection'
  | 'unexpected_control_message'
  | 'device_session_not_found'
  | 'resend_interface_properties_failed'
  | 'empty_cache_error';

function isValidName(name: string): name is DeviceErrorName {
  switch (name) {
    case 'write_on_server_owned_interface':
    case 'invalid_interface':
    case 'invalid_path':
    case 'mapping_not_found':
    case 'interface_loading_failed':
    case 'ambiguous_path':
    case 'undecodable_bson_payload':
    case 'unexpected_value_type':
    case 'value_size_exceeded':
    case 'unexpected_object_key':
    case 'invalid_introspection':
    case 'unexpected_control_message':
    case 'device_session_not_found':
    case 'resend_interface_properties_failed':
    case 'empty_cache_error':
      return true;

    default:
      return false;
  }
}

export class AstarteDeviceErrorEvent extends AstarteDeviceEvent {
  readonly errorName: DeviceErrorName;

  readonly metadata: unknown;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private constructor(arg: any) {
    super(arg);
    if (!arg.event || !_.isPlainObject(arg.event) || arg.event.type !== 'device_error') {
      throw new Error('Invalid event');
    }
    if (typeof arg.event.error_name !== 'string' && !isValidName(arg.event.error_name)) {
      throw new Error('Invalid device error');
    }
    this.errorName = arg.event.error_name;
    this.metadata = arg.event.metadata;
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  static fromJSON(arg: any): AstarteDeviceErrorEvent {
    return new AstarteDeviceErrorEvent(arg);
  }
}
