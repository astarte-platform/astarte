/*
This file is part of Astarte.

Copyright 2023 SECO Mind Srl

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
/* eslint-disable camelcase */

import * as yup from 'yup';
import { AstarteTriggerDeliveryPolicyHandlerDTO } from 'astarte-client/types/dto';

import _ from 'lodash';

interface AstarteTriggerDeliveryPolicyObject {
  name: string;
  error_handlers: AstarteTriggerDeliveryPolicyHandlerDTO[];
  retry_times?: number;
  maximum_capacity: number;
  event_ttl?: number;
}

const isOnFieldEqual = (
  on1: AstarteTriggerDeliveryPolicyHandlerDTO['on'],
  on2: AstarteTriggerDeliveryPolicyHandlerDTO['on'],
) => {
  if (typeof on1 === 'string') {
    return on1 === on2;
  }
  if (typeof on2 === 'string') {
    return false;
  }
  return on1.some((customError) => on2.includes(customError));
};

const AstarteTriggerDeliveryPolicyHandlerDTOSchema = yup.object().shape({
  on: yup
    .mixed()
    .test(
      'is-valid-on',
      'Invalid On field. Must be "client_error" | "server_error" | "any_error" | [<int> (400-599)]!',
      (value) => {
        if (
          typeof value === 'string' &&
          ['any_error', 'client_error', 'server_error'].includes(value)
        ) {
          return true;
        }
        if (Array.isArray(value) && value.length > 0) {
          const uniqueValues: Set<number> = new Set(value);
          return (
            uniqueValues.size === value.length &&
            value.every((item) => Number.isInteger(item) && item >= 400 && item < 600)
          );
        }
        return false;
      },
    )
    .required('on is required'),
  strategy: yup.mixed().oneOf(['discard', 'retry']).required(),
});

const policySchema = yup.object().shape({
  name: yup.string().required().min(1).max(128),
  error_handlers: yup
    .array()
    .of(AstarteTriggerDeliveryPolicyHandlerDTOSchema)
    .test('unique-on', 'On field must be unique between error handlers', (value) => {
      const handlers = (value || []) as AstarteTriggerDeliveryPolicyHandlerDTO[];
      const onFields = handlers.map((handler) => handler.on);
      const uniqueOnFields = _.uniqWith(onFields, isOnFieldEqual);
      return onFields.length === uniqueOnFields.length;
    })
    .required(),
  retry_times: yup
    .number()
    .integer()
    .when('error_handlers', {
      is: (errorHandlers) =>
        errorHandlers.some((e: AstarteTriggerDeliveryPolicyHandlerDTO) => e.strategy === 'retry'),
      then: yup.number().integer().min(1).max(100).required(),
      otherwise: yup.number().integer().max(0).default(0),
    }),
  maximum_capacity: yup.number().integer().min(1).required(),
  event_ttl: yup.number().integer().min(0).max(86400),
});

class AstarteTriggerDeliveryPolicy {
  name: string;

  error_handlers: AstarteTriggerDeliveryPolicyHandlerDTO[];

  maximum_capacity: number;

  retry_times?: number;

  event_ttl?: number;

  constructor(obj: AstarteTriggerDeliveryPolicyObject) {
    const validatedObj = AstarteTriggerDeliveryPolicy.validation.validateSync(obj, {
      abortEarly: false,
    }) as AstarteTriggerDeliveryPolicyObject;
    this.name = validatedObj.name;
    this.error_handlers = validatedObj.error_handlers;
    this.maximum_capacity = validatedObj.maximum_capacity;
    this.retry_times = validatedObj.retry_times;
    this.event_ttl = validatedObj.event_ttl;
  }

  static validation = policySchema;
}

export type { AstarteTriggerDeliveryPolicyObject };

export { AstarteTriggerDeliveryPolicy };
