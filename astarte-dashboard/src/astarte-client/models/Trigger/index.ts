/* eslint-disable no-template-curly-in-string */
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

import * as yup from 'yup';
import _ from 'lodash';

import { AstarteInterface, interfaceNameRegex } from '../Interface';
import { AstarteMapping, mappingEndpointRegex } from '../Mapping';
import { fromAstarteTriggerDTO, toAstarteTriggerDTO } from '../../transforms/trigger';
import type { AstarteTriggerDTO } from '../../types';

type AstarteTriggerJSON = AstarteTriggerDTO;

interface AstarteTriggerHTTPActionObject {
  httpUrl: string;
  httpMethod: 'delete' | 'get' | 'head' | 'options' | 'patch' | 'post' | 'put';
  httpStaticHeaders?: {
    [headerName: string]: string;
  };
  ignoreSslErrors?: boolean;
  templateType?: 'mustache';
  template?: string;
}

interface AstarteTriggerAMQPActionObject {
  amqpExchange: string;
  amqpRoutingKey?: string;
  amqpStaticHeaders?: {
    [headerName: string]: string;
  };
  amqpMessageExpirationMilliseconds: number;
  amqpMessagePriority?: number;
  amqpMessagePersistent: boolean;
}

interface AstarteSimpleDeviceTriggerObject {
  type: 'device_trigger';
  on: 'device_disconnected' | 'device_connected' | 'device_error' | 'device_empty_cache_received';
  deviceId?: string;
  groupName?: string;
}

interface AstarteSimpleDataTriggerObject {
  type: 'data_trigger';
  on:
    | 'incoming_data'
    | 'value_change'
    | 'value_change_applied'
    | 'path_created'
    | 'path_removed'
    | 'value_stored';
  deviceId?: string;
  groupName?: string;
  interfaceName: string;
  interfaceMajor?: number;
  matchPath: string;
  valueMatchOperator: '*' | '==' | '!=' | '>' | '>=' | '<' | '<=' | 'contains' | 'not_contains';
  knownValue?: string | number | boolean;
}

type AstarteSimpleTriggerObject = AstarteSimpleDeviceTriggerObject | AstarteSimpleDataTriggerObject;

interface AstarteTriggerObject {
  name: string;
  action: AstarteTriggerHTTPActionObject | AstarteTriggerAMQPActionObject;
  simpleTriggers: AstarteSimpleTriggerObject[];
}

const reservedHttpHeaders = [
  'connection',
  'content-length',
  'date',
  'host',
  'te',
  'upgrade',
  'x-forwarded-for',
  'x-forwarded-host',
  'x-forwarded-proto',
  'sec-websocket-accept',
  'proxy-authorization',
  'proxy-authenticate',
];

const getAmqpExchangeRegex = (realm?: string | null) =>
  realm
    ? new RegExp(`^astarte_events_${realm}_[a-zA-Z0-9_\\.\\:]+$`)
    : /^astarte_events_[a-zA-Z0-9]+_[a-zA-Z0-9_.:]+$/;

const amqpRoutingKeyRegex = /^[^{}]+$/;

const generateObjectValidation = <K, V>(keySchema: yup.Schema<K>, valueSchema: yup.Schema<V>) => (
  obj: unknown,
) => {
  if (_.isUndefined(obj)) {
    return true;
  }
  return (
    _.isObject(obj) &&
    _.isPlainObject(obj) &&
    Object.entries(obj).every(
      ([key, value]) => keySchema.isValidSync(key) && valueSchema.isValidSync(value),
    )
  );
};

const astarteTriggerHttpActionObjectSchema: yup.ObjectSchema<AstarteTriggerHTTPActionObject> = yup
  .object({
    httpUrl: yup.string().min('http://a'.length).max(8192).required(),
    httpMethod: yup
      .string()
      .oneOf(['delete', 'get', 'head', 'options', 'patch', 'post', 'put'])
      .required(),
    httpStaticHeaders: yup
      .mixed<Record<string, string>>()
      .test(
        'http-static-headers',
        '${path} must be an Object of string -> string',
        generateObjectValidation(
          yup
            .string()
            .required()
            .test(
              'reserved-http-headers',
              '${path} cannot be a reserved HTTP header',
              (headerName) => !reservedHttpHeaders.includes((headerName || '').toLowerCase()),
            ),
          yup.string(),
        ),
      )
      .notRequired(),
    ignoreSslErrors: yup.boolean().notRequired(),
    templateType: yup.string().oneOf(['mustache']).notRequired(),
    template: yup.string().when('templateType', {
      is: 'mustache',
      then: yup
        .string()
        .max(1024 * 1024)
        .required(),
      otherwise: yup.string().strip(true),
    }),
  })
  .required();

const astarteTriggerAmqpActionObjectSchema: yup.ObjectSchema<AstarteTriggerAMQPActionObject> = yup
  .object({
    amqpExchange: yup
      .string()
      .max(255)
      .required()
      .when('$realm', (realm?: string | null) =>
        yup
          .string()
          .matches(
            getAmqpExchangeRegex(realm),
            `\${path} must have astarte_events_${
              realm || '<realm-name>'
            }_<any-allowed-string> format`,
          ),
      ),
    amqpRoutingKey: yup
      .string()
      .matches(amqpRoutingKeyRegex, '${path} must not contain { and }')
      .notRequired(),
    amqpStaticHeaders: yup
      .mixed<Record<string, string>>()
      .test(
        'amqp-static-headers',
        '${path} must be an Object of string -> string',
        generateObjectValidation(yup.string().required(), yup.string()),
      )
      .notRequired(),
    amqpMessageExpirationMilliseconds: yup.number().integer().positive().required(),
    amqpMessagePriority: yup.number().integer().min(0).max(9).notRequired(),
    amqpMessagePersistent: yup.boolean().required(),
  })
  .required();

const astarteTriggerActionObjectSchema = yup.lazy((action) => {
  if ('httpUrl' in (action as AstarteTriggerHTTPActionObject | AstarteTriggerAMQPActionObject)) {
    return astarteTriggerHttpActionObjectSchema;
  }
  return astarteTriggerAmqpActionObjectSchema;
});

const astarteSimpleDeviceTriggerObjectSchema: yup.ObjectSchema<AstarteSimpleDeviceTriggerObject> = yup
  .object({
    type: yup.string().oneOf(['device_trigger']).required(),
    on: yup
      .string()
      .oneOf([
        'device_disconnected',
        'device_connected',
        'device_error',
        'device_empty_cache_received',
      ])
      .required(),
    deviceId: yup.string().notRequired(),
    groupName: yup
      .string()
      .notRequired()
      .when('deviceId', (deviceId: unknown, schema: yup.StringSchema) =>
        deviceId != null ? schema.strip(true) : schema,
      ),
  })
  .required();

const astarteSimpleDataTriggerObjectSchema: yup.ObjectSchema<AstarteSimpleDataTriggerObject> = yup
  .object({
    type: yup.string().oneOf(['data_trigger']).required(),
    on: yup
      .string()
      .oneOf([
        'incoming_data',
        'value_change',
        'value_change_applied',
        'path_created',
        'path_removed',
        'value_stored',
      ])
      .required(),
    deviceId: yup.string().notRequired(),
    groupName: yup
      .string()
      .notRequired()
      .when('deviceId', (deviceId: unknown, schema: yup.StringSchema) =>
        deviceId != null ? schema.strip(true) : schema,
      ),
    interfaceName: yup
      .string()
      .test(
        'interface-name',
        '${path} must be either * or a valid interface name',
        (interfaceName) =>
          interfaceName != null &&
          (interfaceName === '*' || interfaceNameRegex.test(interfaceName)),
      )
      .required(),
    interfaceMajor: yup.number().integer().min(0).notRequired(),
    matchPath: yup
      .string()
      .test(
        'match-path',
        '${path} must be either /* or a valid interface mapping path',
        (matchPath) =>
          matchPath != null && (matchPath === '/*' || mappingEndpointRegex.test(matchPath)),
      )
      // TODO: this is a workaround to a data updater plant limitation
      // see also https://github.com/astarte-platform/astarte/issues/513
      .when('on', (on: AstarteSimpleDataTriggerObject['on'], schema: yup.StringSchema) =>
        schema.test(
          'match-path-limit-for-value-changed',
          `\${path} cannot be /* for value_change or value_change_applied triggers`,
          (matchPath) =>
            matchPath !== '/*' || !['value_change', 'value_change_applied'].includes(on),
        ),
      )
      .required()
      .when(
        ['$interface', 'on', 'valueMatchOperator'],
        (
          iface: AstarteInterface | null,
          on: AstarteSimpleDataTriggerObject['on'],
          valueMatchOperator: AstarteSimpleDataTriggerObject['valueMatchOperator'],
          schema: yup.StringSchema,
        ) =>
          iface == null
            ? schema
            : schema
                .test(
                  'match-path-of-interface',
                  `\${path} must be either /* or a valid mapping path for interface ${iface.name} v${iface.major}.${iface.minor}`,
                  (matchPath) => {
                    if (!matchPath) {
                      return false;
                    }
                    if (matchPath === '/*') {
                      return true;
                    }
                    return iface.mappings.some((m) =>
                      AstarteMapping.matchEndpoint(m.endpoint, matchPath),
                    );
                  },
                )
                // TODO: this is a workaround to for the issue https://github.com/astarte-platform/astarte/issues/523
                .test(
                  'match-path-limit-for-datastream-object-interfaces',
                  `only incoming_data triggers with /* path and * operator are supported for datastream object interfaces`,
                  (matchPath) =>
                    iface.aggregation !== 'object' ||
                    (on === 'incoming_data' && valueMatchOperator === '*' && matchPath === '/*'),
                ),
      ),
    valueMatchOperator: yup
      .string()
      .oneOf(['*', '==', '!=', '>', '>=', '<', '<=', 'contains', 'not_contains'])
      .required(),
    knownValue: yup
      .mixed<string | boolean | number>()
      .when(
        ['matchPath', 'valueMatchOperator', '$interface'],
        (
          matchPath: string | undefined,
          valueMatchOperator: string | undefined,
          iface: AstarteInterface | null,
        ) => {
          if (!iface || !matchPath) {
            return yup.mixed<string | boolean | number>().strip(true);
          }
          const matchMapping = iface.mappings.find((m) =>
            AstarteMapping.matchEndpoint(m.endpoint, matchPath),
          );
          const ifacePathType = matchMapping ? matchMapping.type : null;
          let schema: yup.StringSchema | yup.NumberSchema | yup.BooleanSchema = yup.string<
            string | undefined
          >();
          if (!ifacePathType) {
            schema = yup.string<string | undefined>();
          } else if (['boolean', 'booleanarray'].includes(ifacePathType)) {
            schema = yup.boolean<boolean | undefined>();
          } else if (['double', 'doublearray'].includes(ifacePathType)) {
            schema = yup.number<number | undefined>();
          } else if (['integer', 'integerarray'].includes(ifacePathType)) {
            schema = yup.number().integer();
          }
          return valueMatchOperator === '*' ? schema.strip(true) : schema.required();
        },
      ),
  })
  .required();

const astarteSimpleTriggerObjectSchema = yup.lazy((simpleTrigger) => {
  if (_.get(simpleTrigger, 'type') === 'device_trigger') {
    return astarteSimpleDeviceTriggerObjectSchema;
  }
  return astarteSimpleDataTriggerObjectSchema;
});

const astarteTriggerObjectSchema: yup.ObjectSchema<AstarteTriggerObject> = yup
  .object({
    name: yup.string().required(),
    action: astarteTriggerActionObjectSchema,
    simpleTriggers: yup.array(astarteSimpleTriggerObjectSchema).required(),
  })
  .required();

type AstarteTriggerHTTPAction = AstarteTriggerHTTPActionObject;
type AstarteTriggerAMQPAction = AstarteTriggerAMQPActionObject;
type AstarteSimpleDeviceTrigger = AstarteSimpleDeviceTriggerObject;
type AstarteSimpleDataTrigger = AstarteSimpleDataTriggerObject;
type AstarteSimpleTrigger = AstarteSimpleDeviceTrigger | AstarteSimpleDataTrigger;

class AstarteTrigger {
  name: string;

  action: AstarteTriggerHTTPAction | AstarteTriggerAMQPAction;

  simpleTriggers: AstarteSimpleTrigger[];

  constructor(obj: AstarteTriggerObject) {
    const validatedObj = AstarteTrigger.validation.validateSync(obj, { abortEarly: false });
    this.name = validatedObj.name;
    this.action = validatedObj.action;
    this.simpleTriggers = validatedObj.simpleTriggers;
  }

  static validation = astarteTriggerObjectSchema;

  static fromJSON(json: AstarteTriggerJSON): AstarteTrigger {
    return fromAstarteTriggerDTO(json);
  }

  static toJSON(trigger: AstarteTrigger): AstarteTriggerJSON {
    return toAstarteTriggerDTO(trigger);
  }
}

export type {
  AstarteTriggerHTTPActionObject,
  AstarteTriggerAMQPActionObject,
  AstarteTriggerHTTPAction,
  AstarteTriggerAMQPAction,
  AstarteSimpleDeviceTrigger,
  AstarteSimpleDataTrigger,
  AstarteSimpleTrigger,
};

export { AstarteTrigger };
