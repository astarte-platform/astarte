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

import {
  AstarteTrigger,
  AstarteTriggerHTTPActionObject,
  AstarteTriggerAMQPActionObject,
} from '../models/Trigger';
import type {
  AstarteTriggerDTO,
  AstarteTriggerHTTPActionDTO,
  AstarteTriggerAMQPActionDTO,
} from '../types';

export const fromAstarteTriggerDTO = (dto: AstarteTriggerDTO): AstarteTrigger => {
  let action;
  if ('http_url' in dto.action && dto.action.http_url != null) {
    const dtoAction = dto.action as AstarteTriggerHTTPActionDTO;
    action = {
      httpUrl: dtoAction.http_url,
      httpMethod: dtoAction.http_method,
      httpStaticHeaders: dtoAction.http_static_headers,
      ignoreSslErrors: dtoAction.ignore_ssl_errors,
      templateType: dtoAction.template_type,
      template: dtoAction.template,
    };
  } else {
    const dtoAction = dto.action as AstarteTriggerAMQPActionDTO;
    action = {
      amqpExchange: dtoAction.amqp_exchange,
      amqpRoutingKey: dtoAction.amqp_routing_key,
      amqpStaticHeaders: dtoAction.amqp_static_headers,
      amqpMessageExpirationMilliseconds: dtoAction.amqp_message_expiration_ms,
      amqpMessagePriority: dtoAction.amqp_message_priority,
      amqpMessagePersistent: dtoAction.amqp_message_persistent,
    };
  }
  return new AstarteTrigger({
    name: dto.name,
    action,
    simpleTriggers: dto.simple_triggers.map((simpleTriggerDTO) =>
      simpleTriggerDTO.type === 'device_trigger'
        ? {
            type: simpleTriggerDTO.type,
            on: simpleTriggerDTO.on,
            deviceId: simpleTriggerDTO.device_id,
            groupName: simpleTriggerDTO.group_name,
          }
        : {
            type: simpleTriggerDTO.type,
            on: simpleTriggerDTO.on,
            deviceId: simpleTriggerDTO.device_id,
            groupName: simpleTriggerDTO.group_name,
            interfaceName: simpleTriggerDTO.interface_name,
            interfaceMajor: simpleTriggerDTO.interface_major,
            matchPath: simpleTriggerDTO.match_path,
            valueMatchOperator: simpleTriggerDTO.value_match_operator,
            knownValue: simpleTriggerDTO.known_value,
          },
    ),
  });
};

export const toAstarteTriggerDTO = (trigger: AstarteTrigger): AstarteTriggerDTO => {
  let action;
  if ('httpUrl' in trigger.action && trigger.action.httpUrl != null) {
    const triggerAction = trigger.action as AstarteTriggerHTTPActionObject;
    action = {
      http_url: triggerAction.httpUrl,
      http_method: triggerAction.httpMethod,
      http_static_headers: triggerAction.httpStaticHeaders,
      ignore_ssl_errors: triggerAction.ignoreSslErrors,
      template_type: triggerAction.templateType,
      template: triggerAction.template,
    };
  } else {
    const triggerAction = trigger.action as AstarteTriggerAMQPActionObject;
    action = {
      amqp_exchange: triggerAction.amqpExchange,
      amqp_routing_key: triggerAction.amqpRoutingKey,
      amqp_static_headers: triggerAction.amqpStaticHeaders,
      amqp_message_expiration_ms: triggerAction.amqpMessageExpirationMilliseconds,
      amqp_message_priority: triggerAction.amqpMessagePriority,
      amqp_message_persistent: triggerAction.amqpMessagePersistent,
    };
  }
  return {
    name: trigger.name,
    action,
    simple_triggers: trigger.simpleTriggers.map((simpleTrigger) =>
      simpleTrigger.type === 'device_trigger'
        ? {
            type: simpleTrigger.type,
            on: simpleTrigger.on,
            device_id: simpleTrigger.deviceId,
            group_name: simpleTrigger.groupName,
          }
        : {
            type: simpleTrigger.type,
            on: simpleTrigger.on,
            device_id: simpleTrigger.deviceId,
            group_name: simpleTrigger.groupName,
            interface_name: simpleTrigger.interfaceName,
            interface_major: simpleTrigger.interfaceMajor,
            match_path: simpleTrigger.matchPath,
            value_match_operator: simpleTrigger.valueMatchOperator,
            known_value: simpleTrigger.knownValue,
          },
    ),
  };
};
