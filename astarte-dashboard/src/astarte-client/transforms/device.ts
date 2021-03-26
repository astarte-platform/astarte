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

import { AstarteDevice } from '../models/Device';

import type { AstarteDeviceInterfaceStats } from '../models/Device';
import type { AstarteDeviceDTO } from '../types';

const fromInterfaceStatsDTO = (
  iface: NonNullable<AstarteDeviceDTO['previous_interfaces']>[number],
): AstarteDeviceInterfaceStats => ({
  name: iface.name,
  major: iface.major,
  minor: iface.minor,
  exchangedMessages: iface.exchanged_msgs || 0,
  exchangedBytes: iface.exchanged_bytes || 0,
});

const toInterfaceStatsDTO = (iface: AstarteDeviceInterfaceStats) => ({
  name: iface.name,
  major: iface.major,
  minor: iface.minor,
  exchanged_msgs: iface.exchangedMessages,
  exchanged_bytes: iface.exchangedBytes,
});

export const fromAstarteDeviceDTO = (dto: AstarteDeviceDTO): AstarteDevice =>
  new AstarteDevice({
    id: dto.id,
    isConnected: !!dto.connected,
    hasCredentialsInhibited: !!dto.credentials_inhibited,
    aliases: new Map(Object.entries(dto.aliases || {})),
    groups: dto.groups || [],
    introspection: new Map(
      Object.entries(dto.introspection || {}).map(([interfaceName, iface]) => [
        interfaceName,
        fromInterfaceStatsDTO({ name: interfaceName, ...iface }),
      ]),
    ),
    metadata: new Map(Object.entries(dto.metadata || {})),
    totalReceivedMessages: dto.total_received_msgs || 0,
    totalReceivedBytes: dto.total_received_bytes || 0,
    previousInterfaces: (dto.previous_interfaces || []).map(fromInterfaceStatsDTO),
    firstRegistration:
      dto.first_registration != null ? new Date(dto.first_registration) : undefined,
    firstCredentialsRequest:
      dto.first_credentials_request != null ? new Date(dto.first_credentials_request) : undefined,
    lastDisconnection:
      dto.last_disconnection != null ? new Date(dto.last_disconnection) : undefined,
    lastConnection: dto.last_connection != null ? new Date(dto.last_connection) : undefined,
    lastSeenIp: dto.last_seen_ip != null ? dto.last_seen_ip : undefined,
    lastCredentialsRequestIp:
      dto.last_credentials_request_ip != null ? dto.last_credentials_request_ip : undefined,
  });

export const toAstarteDeviceDTO = (obj: AstarteDevice): AstarteDeviceDTO => ({
  id: obj.id,
  connected: !!obj.isConnected,
  credentials_inhibited: !!obj.hasCredentialsInhibited,
  aliases: Object.fromEntries(obj.aliases),
  groups: obj.groups || [],
  introspection: _.mapValues(Object.fromEntries(obj.introspection), (iface) =>
    toInterfaceStatsDTO(iface),
  ),
  metadata: Object.fromEntries(obj.metadata),
  total_received_msgs: obj.totalReceivedMessages || 0,
  total_received_bytes: obj.totalReceivedBytes || 0,
  previous_interfaces: (obj.previousInterfaces || []).map(toInterfaceStatsDTO),
  first_registration:
    obj.firstRegistration != null ? obj.firstRegistration.toISOString() : undefined,
  first_credentials_request:
    obj.firstCredentialsRequest != null ? obj.firstCredentialsRequest.toISOString() : undefined,
  last_disconnection:
    obj.lastDisconnection != null ? obj.lastDisconnection.toISOString() : undefined,
  last_connection: obj.lastConnection != null ? obj.lastConnection.toISOString() : undefined,
  last_seen_ip: obj.lastSeenIp != null ? obj.lastSeenIp : undefined,
  last_credentials_request_ip:
    obj.lastCredentialsRequestIp != null ? obj.lastCredentialsRequestIp : undefined,
});
