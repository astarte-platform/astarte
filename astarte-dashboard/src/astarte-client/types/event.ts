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

import type { AstarteDataType } from './dataType';

interface AstarteDeviceConnectedEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'device_connected';
    device_ip_address: string;
  };
}

interface AstarteDeviceDisconnectedEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'device_disconnected';
  };
}

interface AstarteDeviceErrorEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'device_error';
    error_name:
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
    metadata: { [key: string]: string };
  };
}

interface AstarteDeviceUnsetPropertyEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'incoming_data';
    interface: string;
    path: string;
    value: null;
  };
}

interface AstarteDeviceValueEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'incoming_data';
    interface: string;
    path: string;
    value: AstarteDataType | { [key: string]: AstarteDataType };
  };
}

type AstarteDeviceIncomingDataEvent = AstarteDeviceUnsetPropertyEvent | AstarteDeviceValueEvent;

interface AstarteDeviceValueStoredEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'value_stored';
    interface: string;
    path: string;
    value: AstarteDataType | { [key: string]: AstarteDataType };
  };
}

interface AstarteDeviceValueChangedEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'value_changed';
    interface: string;
    path: string;
    old_value: AstarteDataType | { [key: string]: AstarteDataType };
    new_value: AstarteDataType | { [key: string]: AstarteDataType };
  };
}

interface AstarteDeviceValueChangedAppliedEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'value_change_applied';
    interface: string;
    path: string;
    old_value: AstarteDataType | { [key: string]: AstarteDataType };
    new_value: AstarteDataType | { [key: string]: AstarteDataType };
  };
}

interface AstarteDevicePathCreatedEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'path_created';
    interface: string;
    path: string;
    value: AstarteDataType | { [key: string]: AstarteDataType };
  };
}

interface AstarteDevicePathRemovedEvent {
  device_id: string;
  timestamp: number;
  event: {
    type: 'path_removed';
    interface: string;
    path: string;
  };
}

export type AstarteDeviceEvent =
  | AstarteDeviceConnectedEvent
  | AstarteDeviceDisconnectedEvent
  | AstarteDeviceErrorEvent
  | AstarteDeviceIncomingDataEvent
  | AstarteDeviceValueStoredEvent
  | AstarteDeviceValueChangedEvent
  | AstarteDeviceValueChangedAppliedEvent
  | AstarteDevicePathCreatedEvent
  | AstarteDevicePathRemovedEvent;
