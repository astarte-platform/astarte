/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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
/* eslint camelcase: 0 */

interface AstarteSimpleDeviceTriggerDTO {
  type: 'device_trigger';
  on: 'device_disconnected' | 'device_connected' | 'device_error' | 'device_empty_cache_received';
  device_id?: string;
  group_name?: string;
}

interface AstarteSimpleDataTriggerDTO {
  type: 'data_trigger';
  on:
    | 'incoming_data'
    | 'value_change'
    | 'value_change_applied'
    | 'path_created'
    | 'path_removed'
    | 'value_stored';
  device_id?: string;
  group_name?: string;
  interface_name: string;
  interface_major?: number;
  match_path: string;
  value_match_operator: '*' | '==' | '!=' | '>' | '>=' | '<' | '<=' | 'contains' | 'not_contains';
  known_value?: string | number | boolean;
}

type AstarteSimpleTriggerDTO = AstarteSimpleDeviceTriggerDTO | AstarteSimpleDataTriggerDTO;

interface AstarteTriggerHTTPActionDTO {
  http_url: string;
  http_method: 'delete' | 'get' | 'head' | 'options' | 'patch' | 'post' | 'put';
  http_static_headers?: {
    [headerName: string]: string;
  };
  ignore_ssl_errors?: boolean;
  template_type?: 'mustache';
  template?: string;
}

interface AstarteTriggerAMQPActionDTO {
  amqp_exchange: string;
  amqp_routing_key?: string;
  amqp_static_headers?: {
    [headerName: string]: string;
  };
  amqp_message_expiration_ms: number;
  amqp_message_priority?: number;
  amqp_message_persistent: boolean;
}

interface AstarteTriggerDTO {
  name: string;
  action: AstarteTriggerHTTPActionDTO | AstarteTriggerAMQPActionDTO;
  simple_triggers: AstarteSimpleTriggerDTO[];
}

interface AstarteTransientTriggerDTO {
  name: string;
  device_id?: string;
  group_name?: string;
  simple_trigger: AstarteSimpleTriggerDTO;
}

export {
  AstarteTransientTriggerDTO,
  AstarteTriggerDTO,
  AstarteTriggerHTTPActionDTO,
  AstarteTriggerAMQPActionDTO,
};
