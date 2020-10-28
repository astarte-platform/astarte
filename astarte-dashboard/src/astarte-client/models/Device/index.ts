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

import { AstarteDeviceDTO } from '../../types';

export class AstarteDevice {
  id: string;

  aliases: Map<string, string>;

  metadata: Map<string, string>;

  isConnected: boolean;

  introspection: {
    [interfaceName: string]: {
      major: number;
      minor: number;
      exchangedMessages?: number;
      exchangedBytes?: number;
    };
  };

  totalReceivedMessages: number;

  totalReceivedBytes: number;

  hasCredentialsInhibited: boolean;

  groups: string[];

  previousInterfaces: Array<{
    name: string;
    major: string;
    minor: string;
    exchangedMessages?: number;
    exchangedBytes?: number;
  }>;

  firstRegistration?: Date;

  firstCredentialsRequest?: Date;

  lastDisconnection?: Date;

  lastConnection?: Date;

  lastSeenIp?: string;

  lastCredentialsRequestIp?: string;

  constructor(device: AstarteDeviceDTO) {
    this.id = device.id;
    this.isConnected = !!device.connected;
    this.hasCredentialsInhibited = !!device.credentials_inhibited;
    this.aliases = new Map();
    if (device.aliases) {
      Object.entries(device.aliases).forEach(([key, value]) => {
        this.aliases.set(key, value);
      });
    }
    this.groups = device.groups || [];
    this.introspection = {};
    if (device.introspection) {
      Object.entries(device.introspection).forEach(([interfaceName, iface]) => {
        this.introspection[interfaceName] = {
          major: iface.major,
          minor: iface.minor,
          exchangedMessages: iface.exchanged_msgs,
          exchangedBytes: iface.exchanged_bytes,
        };
      });
    }
    this.metadata = new Map();
    if (device.metadata) {
      Object.entries(device.metadata).forEach(([key, value]) => {
        this.metadata.set(key, value);
      });
    }
    this.totalReceivedMessages = device.total_received_msgs || 0;
    this.totalReceivedBytes = device.total_received_bytes || 0;
    this.previousInterfaces = (device.previous_interfaces || []).map((iface) => ({
      name: iface.name,
      major: iface.major,
      minor: iface.minor,
      exchangedMessages: iface.exchanged_msgs,
      exchangedBytes: iface.exchanged_bytes,
    }));
    if (device.first_registration) {
      this.firstRegistration = new Date(device.first_registration);
    }
    if (device.first_credentials_request) {
      this.firstCredentialsRequest = new Date(device.first_credentials_request);
    }
    if (device.last_disconnection) {
      this.lastDisconnection = new Date(device.last_disconnection);
    }
    if (device.last_connection) {
      this.lastConnection = new Date(device.last_connection);
    }
    if (device.last_seen_ip) {
      this.lastSeenIp = device.last_seen_ip;
    }
    if (device.last_credentials_request_ip) {
      this.lastCredentialsRequestIp = device.last_credentials_request_ip;
    }
  }

  get hasNameAlias(): boolean {
    return this.aliases.has('name');
  }

  get name(): string {
    if (this.hasNameAlias) {
      return this.aliases.get('name') as string;
    }
    return this.id;
  }

  static fromObject(dto: AstarteDeviceDTO): AstarteDevice {
    return new AstarteDevice(dto);
  }
}
