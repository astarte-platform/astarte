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

import axios from 'axios';
import { Socket as PhoenixSocket } from 'phoenix';
import _ from 'lodash';

import {
  AstarteDataTreeNode,
  fromAstarteDeviceDTO,
  fromAstarteInterfaceDTO,
  toAstarteInterfaceDTO,
  fromAstartePipelineDTO,
  toAstartePipelineDTO,
  toAstarteDataTree,
} from './transforms';
import * as definitions from './definitions';
import { AstarteCustomBlock, toAstarteBlock } from './models/Block';
import { AstarteDevice } from './models/Device';
import { AstarteFlow } from './models/Flow';
import { AstartePipeline } from './models/Pipeline';
import type { AstarteInterface } from './models/Interface';
import type { AstarteBlock } from './models/Block';
import type {
  AstarteBlockDTO,
  AstarteDeviceDTO,
  AstarteInterfaceValues,
  AstartePropertyData,
  AstarteDatastreamIndividualData,
  AstarteDatastreamObjectData,
} from './types';
import { AstarteDeviceEvent, decodeEvent } from './types/events';

export type AstarteClientEvent = 'credentialsChange' | 'socketError' | 'socketClose';

export interface AstarteInterfaceDescriptor {
  name: string;
  major: number;
  minor: number;
}
type Channel = any;
type Trigger = any;

type InterfaceOrInterfaceNameParams =
  | { interfaceName: AstarteInterface['name'] }
  | { interface: AstarteInterface };

// Wrap phoenix lib calls in promise for async handling
async function openNewSocketConnection(
  connectionParams: any,
  onErrorHanlder: any,
  onCloseHandler: any,
): Promise<PhoenixSocket> {
  const { socketUrl, realm, token } = connectionParams;

  return new Promise((resolve) => {
    const phoenixSocket = new PhoenixSocket(socketUrl, {
      params: {
        realm,
        token,
      },
    });
    phoenixSocket.onError((e: any) => onErrorHanlder(e));
    phoenixSocket.onClose((e: any) => onCloseHandler(e));
    phoenixSocket.onOpen(() => {
      resolve(phoenixSocket);
    });
    phoenixSocket.connect();
  });
}

async function joinChannel(phoenixSocket: PhoenixSocket, channelString: string): Promise<Channel> {
  return new Promise((resolve, reject) => {
    const channel = phoenixSocket.channel(channelString, {});
    channel
      .join()
      .receive('ok', () => {
        resolve(channel);
      })
      .receive('error', (err: any) => {
        reject(err);
      });
  });
}

async function leaveChannel(channel: Channel): Promise<void> {
  return new Promise((resolve, reject) => {
    channel
      .leave()
      .receive('ok', () => {
        resolve();
      })
      .receive('error', (err: any) => {
        reject(err);
      });
  });
}

async function registerTrigger(channel: Channel, triggerPayload: Trigger): Promise<void> {
  return new Promise((resolve, reject) => {
    channel
      .push('watch', triggerPayload)
      .receive('ok', () => {
        resolve();
      })
      .receive('error', (err: any) => {
        reject(err);
      });
  });
}

function astarteAPIurl(strings: any, baseUrl: any, ...keys: any) {
  return (...values: any) => {
    const dict = values[values.length - 1] || {};
    const result = [strings[1]];
    keys.forEach((key: any, i: any) => {
      const value = Number.isInteger(key) ? values[key] : dict[key];
      result.push(value, strings[i + 2]);
    });
    return new URL(result.join(''), baseUrl);
  };
}

interface AstarteClientConfig {
  appengineUrl: string;
  enableFlowPreview?: boolean;
  flowUrl: string;
  onSocketClose?: () => any;
  onSocketError?: () => any;
  pairingUrl: string;
  realm?: string;
  realmManagementUrl: string;
  token?: string;
}

class AstarteClient {
  private config: { realm: string; enableFlowPreview: boolean };

  private apiConfig: any;

  private joinedChannels: {
    [roomName: string]: Channel;
  };

  private listeners: {
    [eventName: string]: Array<() => any>;
  };

  private onSocketClose?: () => any;

  private onSocketError?: () => any;

  private phoenixSocket: PhoenixSocket | null;

  private token: string;

  constructor(config: AstarteClientConfig) {
    this.config = {
      enableFlowPreview: config.enableFlowPreview || false,
      realm: config.realm || '',
    };

    this.token = config.token || '';

    this.onSocketClose = config.onSocketClose;
    this.onSocketError = config.onSocketError;

    this.phoenixSocket = null;
    this.joinedChannels = {};
    this.listeners = {};

    this.getConfigAuth = this.getConfigAuth.bind(this);
    this.getBlocks = this.getBlocks.bind(this);
    this.getDeviceData = this.getDeviceData.bind(this);
    this.getDevicesStats = this.getDevicesStats.bind(this);
    this.getInterfaceNames = this.getInterfaceNames.bind(this);
    this.getTriggerNames = this.getTriggerNames.bind(this);
    this.getAppengineHealth = this.getAppengineHealth.bind(this);
    this.getRealmManagementHealth = this.getRealmManagementHealth.bind(this);
    this.getPairingHealth = this.getPairingHealth.bind(this);
    this.getFlowHealth = this.getFlowHealth.bind(this);
    this.getPipeline = this.getPipeline.bind(this);
    this.getPipelines = this.getPipelines.bind(this);

    // prettier-ignore
    this.apiConfig = {
      realmManagementHealth: astarteAPIurl`${config.realmManagementUrl}health`,
      auth:                  astarteAPIurl`${config.realmManagementUrl}v1/${'realm'}/config/auth`,
      interfaces:            astarteAPIurl`${config.realmManagementUrl}v1/${'realm'}/interfaces`,
      interfaceMajors:       astarteAPIurl`${config.realmManagementUrl}v1/${'realm'}/interfaces/${'interfaceName'}`,
      interface:             astarteAPIurl`${config.realmManagementUrl}v1/${'realm'}/interfaces/${'interfaceName'}/${'interfaceMajor'}`,
      interfaceData:         astarteAPIurl`${config.realmManagementUrl}v1/${'realm'}/interfaces/${'interfaceName'}/${'interfaceMajor'}`,
      triggers:              astarteAPIurl`${config.realmManagementUrl}v1/${'realm'}/triggers`,
      appengineHealth:       astarteAPIurl`${config.appengineUrl}health`,
      devicesStats:          astarteAPIurl`${config.appengineUrl}v1/${'realm'}/stats/devices`,
      devices:               astarteAPIurl`${config.appengineUrl}v1/${'realm'}/devices`,
      deviceInfo:            astarteAPIurl`${config.appengineUrl}v1/${'realm'}/devices/${'deviceId'}`,
      deviceData:            astarteAPIurl`${config.appengineUrl}v1/${'realm'}/devices/${'deviceId'}/interfaces/${'interfaceName'}`,
      groups:                astarteAPIurl`${config.appengineUrl}v1/${'realm'}/groups`,
      groupDevices:          astarteAPIurl`${config.appengineUrl}v1/${'realm'}/groups/${'groupName'}/devices`,
      deviceInGroup:         astarteAPIurl`${config.appengineUrl}v1/${'realm'}/groups/${'groupName'}/devices/${'deviceId'}`,
      phoenixSocket:         astarteAPIurl`${config.appengineUrl}v1/socket`,
      pairingHealth:         astarteAPIurl`${config.pairingUrl}health`,
      registerDevice:        astarteAPIurl`${config.pairingUrl}v1/${'realm'}/agent/devices`,
      deviceAgent:           astarteAPIurl`${config.pairingUrl}v1/${'realm'}/agent/devices/${'deviceId'}`,
      flowHealth:            astarteAPIurl`${config.flowUrl}health`,
      flows:                 astarteAPIurl`${config.flowUrl}v1/${'realm'}/flows`,
      flowInstance:          astarteAPIurl`${config.flowUrl}v1/${'realm'}/flows/${'instanceName'}`,
      pipelines:             astarteAPIurl`${config.flowUrl}v1/${'realm'}/pipelines`,
      pipelineSource:        astarteAPIurl`${config.flowUrl}v1/${'realm'}/pipelines/${'pipelineId'}`,
      blocks:                astarteAPIurl`${config.flowUrl}v1/${'realm'}/blocks`,
      blockSource:           astarteAPIurl`${config.flowUrl}v1/${'realm'}/blocks/${'blockId'}`,
    };
  }

  addListener(eventName: AstarteClientEvent, callback: () => void): void {
    if (!this.listeners[eventName]) {
      this.listeners[eventName] = [];
    }

    this.listeners[eventName].push(callback);
  }

  removeListener(eventName: AstarteClientEvent, callback: () => void): void {
    const previousListeners = this.listeners[eventName];
    if (previousListeners) {
      this.listeners[eventName] = previousListeners.filter((listener) => listener !== callback);
    }
  }

  private dispatch(eventName: AstarteClientEvent): void {
    const listeners = this.listeners[eventName];
    if (listeners) {
      listeners.forEach((listener) => listener());
    }
  }

  setCredentials({ realm, token }: any): void {
    this.config.realm = realm || '';
    this.token = token || '';

    this.dispatch('credentialsChange');
  }

  async getConfigAuth(): Promise<{ publicKey: string }> {
    const response = await this.$get(this.apiConfig.auth(this.config));
    return { publicKey: response.data.jwt_public_key_pem };
  }

  async updateConfigAuth(params: { publicKey: string }): Promise<void> {
    await this.$put(this.apiConfig.auth(this.config), {
      jwt_public_key_pem: params.publicKey,
    });
  }

  async getInterfaceNames(): Promise<string[]> {
    const response = await this.$get(this.apiConfig.interfaces(this.config));
    return response.data;
  }

  async getInterfaceMajors(interfaceName: string): Promise<number[]> {
    const response = await this.$get(
      this.apiConfig.interfaceMajors({ ...this.config, interfaceName }),
    );
    return response.data;
  }

  async getInterface(params: {
    interfaceName: AstarteInterface['name'];
    interfaceMajor: AstarteInterface['major'];
  }): Promise<AstarteInterface> {
    const { interfaceName, interfaceMajor } = params;
    const response = await this.$get(
      this.apiConfig.interfaceData({
        interfaceName,
        interfaceMajor,
        ...this.config,
      }),
    );
    return fromAstarteInterfaceDTO(response.data);
  }

  async installInterface(iface: AstarteInterface): Promise<void> {
    await this.$post(this.apiConfig.interfaces(this.config), toAstarteInterfaceDTO(iface));
  }

  async updateInterface(iface: AstarteInterface): Promise<void> {
    await this.$put(
      this.apiConfig.interface({
        interfaceName: iface.name,
        interfaceMajor: iface.major,
        ...this.config,
      }),
      toAstarteInterfaceDTO(iface),
    );
  }

  async deleteInterface(
    interfaceName: AstarteInterface['name'],
    interfaceMajor: AstarteInterface['major'],
  ): Promise<void> {
    await this.$delete(this.apiConfig.interface({ ...this.config, interfaceName, interfaceMajor }));
  }

  async getTriggerNames(): Promise<string[]> {
    const response = await this.$get(this.apiConfig.triggers(this.config));
    return response.data;
  }

  async getDevicesStats(): Promise<any> {
    const response = await this.$get(this.apiConfig.devicesStats(this.config));
    return response.data;
  }

  async getDevices(params: {
    details?: boolean;
    from?: string;
    limit?: number;
  }): Promise<{ devices: AstarteDevice[]; nextToken: string | null }> {
    const endpointUri = new URL(this.apiConfig.devices(this.config));
    const query: any = {};
    if (params.details) {
      query.details = true;
    }
    if (params.limit) {
      query.limit = params.limit;
    }
    if (params.from) {
      query.from_token = params.from;
    }
    endpointUri.search = new URLSearchParams(query).toString();
    const response = await this.$get(endpointUri.toString());
    const devices = response.data.map((device: AstarteDeviceDTO) => fromAstarteDeviceDTO(device));
    const nextToken = new URLSearchParams(response.links.next).get('from_token');
    return { devices, nextToken };
  }

  async getDeviceInfo(deviceId: AstarteDevice['id']): Promise<AstarteDevice> {
    const response = await this.$get(this.apiConfig.deviceInfo({ deviceId, ...this.config }));
    return fromAstarteDeviceDTO(response.data);
  }

  async insertDeviceAlias(
    deviceId: AstarteDevice['id'],
    aliasKey: string,
    aliasValue: string,
  ): Promise<void> {
    await this.$patch(this.apiConfig.deviceInfo({ deviceId, ...this.config }), {
      aliases: { [aliasKey]: aliasValue },
    });
  }

  async deleteDeviceAlias(deviceId: AstarteDevice['id'], aliasKey: string): Promise<void> {
    await this.$patch(this.apiConfig.deviceInfo({ deviceId, ...this.config }), {
      aliases: { [aliasKey]: null },
    });
  }

  async insertDeviceMetadata(
    deviceId: AstarteDevice['id'],
    metadataKey: string,
    metadataValue: string,
  ): Promise<void> {
    await this.$patch(this.apiConfig.deviceInfo({ deviceId, ...this.config }), {
      metadata: { [metadataKey]: metadataValue },
    });
  }

  async deleteDeviceMetadata(deviceId: AstarteDevice['id'], metadataKey: string): Promise<void> {
    await this.$patch(this.apiConfig.deviceInfo({ deviceId, ...this.config }), {
      metadata: { [metadataKey]: null },
    });
  }

  async inhibitDeviceCredentialsRequests(
    deviceId: AstarteDevice['id'],
    inhibit: boolean,
  ): Promise<void> {
    await this.$patch(this.apiConfig.deviceInfo({ deviceId, ...this.config }), {
      credentials_inhibited: inhibit,
    });
  }

  async getDeviceData(params: {
    deviceId: AstarteDevice['id'];
    interfaceName: AstarteInterface['name'];
  }): Promise<AstarteInterfaceValues> {
    const response = await this.$get(
      this.apiConfig.deviceData({
        deviceId: params.deviceId,
        interfaceName: params.interfaceName,
        ...this.config,
      }),
    );
    return response.data;
  }

  async getDeviceDataTree(
    params: { deviceId: AstarteDevice['id'] } & InterfaceOrInterfaceNameParams,
  ): Promise<
    | AstarteDataTreeNode<AstartePropertyData>
    | AstarteDataTreeNode<AstarteDatastreamIndividualData>
    | AstarteDataTreeNode<AstarteDatastreamObjectData>
  > {
    let iface: AstarteInterface;
    if ('interface' in params) {
      iface = params.interface;
    } else {
      const device = await this.getDeviceInfo(params.deviceId);
      const interfaceIntrospection = device.introspection.get(params.interfaceName);
      if (!interfaceIntrospection) {
        throw new Error(`Could not find interface ${params.interfaceName} in device introspection`);
      }
      iface = await this.getInterface({
        interfaceName: params.interfaceName,
        interfaceMajor: interfaceIntrospection.major,
      });
    }
    const interfaceValues = await this.getDeviceData({
      deviceId: params.deviceId,
      interfaceName: iface.name,
    });
    return toAstarteDataTree({
      interface: iface,
      data: interfaceValues,
    });
  }

  async getGroupList(): Promise<string[]> {
    const response = await this.$get(this.apiConfig.groups(this.config));
    return response.data;
  }

  async createGroup(params: {
    groupName: string;
    deviceIds: AstarteDevice['id'][];
  }): Promise<void> {
    const { groupName, deviceIds } = params;
    await this.$post(this.apiConfig.groups(this.config), {
      group_name: groupName,
      devices: deviceIds,
    });
  }

  async getDevicesInGroup(params: {
    groupName: string;
    details?: boolean;
  }): Promise<AstarteDevice[]> {
    const { groupName, details } = params;
    if (!groupName) {
      throw new Error('Invalid group name');
    }
    /* Double encoding to preserve the URL format when groupName contains % and / */
    const encodedGroupName = encodeURIComponent(encodeURIComponent(groupName));
    const endpointUri = new URL(
      this.apiConfig.groupDevices({
        ...this.config,
        groupName: encodedGroupName,
      }),
    );
    if (details) {
      endpointUri.search = new URLSearchParams({ details: 'true' }).toString();
    }
    const response = await this.$get(endpointUri.toString());
    return response.data.map((device: AstarteDeviceDTO) => fromAstarteDeviceDTO(device));
  }

  async addDeviceToGroup(params: { groupName: string; deviceId: string }): Promise<void> {
    const { groupName, deviceId } = params;

    if (!groupName) {
      throw new Error('Invalid group name');
    }

    if (!deviceId) {
      throw new Error('Invalid device ID');
    }

    /* Double encoding to preserve the URL format when groupName contains % and / */
    const encodedGroupName = encodeURIComponent(encodeURIComponent(groupName));

    await this.$post(
      this.apiConfig.groupDevices({
        ...this.config,
        groupName: encodedGroupName,
      }),
      { device_id: deviceId },
    );
  }

  async removeDeviceFromGroup(params: { groupName: string; deviceId: string }): Promise<void> {
    const { groupName, deviceId } = params;

    if (!groupName) {
      throw new Error('Invalid group name');
    }

    if (!deviceId) {
      throw new Error('Invalid device ID');
    }

    /* Double encoding to preserve the URL format when groupName contains % and / */
    const encodedGroupName = encodeURIComponent(encodeURIComponent(groupName));

    await this.$delete(
      this.apiConfig.deviceInGroup({
        ...this.config,
        groupName: encodedGroupName,
        deviceId,
      }),
    );
  }

  async registerDevice(params: {
    deviceId: AstarteDevice['id'];
    introspection?: { [interfaceName: string]: AstarteInterfaceDescriptor };
  }): Promise<{ credentialsSecret: string }> {
    const { deviceId, introspection } = params;
    const requestBody: any = {
      hw_id: deviceId,
    };
    if (introspection) {
      const initialIntrospection = _.mapValues(introspection, (interfaceDescriptor) =>
        _.pick(interfaceDescriptor, ['minor', 'major']),
      );
      requestBody.initial_introspection = initialIntrospection;
    }
    const response = await this.$post(this.apiConfig.registerDevice(this.config), requestBody);
    return { credentialsSecret: response.data.credentials_secret };
  }

  async wipeDeviceCredentials(deviceId: AstarteDevice['id']): Promise<void> {
    await this.$delete(this.apiConfig.deviceAgent({ deviceId, ...this.config }));
  }

  async getFlowInstances(): Promise<Array<AstarteFlow['name']>> {
    const response = await this.$get(this.apiConfig.flows(this.config));
    return response.data;
  }

  async getFlowDetails(flowName: AstarteFlow['name']): Promise<AstarteFlow> {
    const response = await this.$get(
      this.apiConfig.flowInstance({ ...this.config, instanceName: flowName }),
    );
    return AstarteFlow.fromObject(response.data);
  }

  async createNewFlowInstance(params: {
    name: AstarteFlow['name'];
    pipeline: string;
    config: { [key: string]: any };
  }): Promise<void> {
    await this.$post(this.apiConfig.flows(this.config), params);
  }

  async deleteFlowInstance(flowName: AstarteFlow['name']): Promise<void> {
    await this.$delete(this.apiConfig.flowInstance({ ...this.config, instanceName: flowName }));
  }

  async getPipelineNames(): Promise<Array<AstartePipeline['name']>> {
    const response = await this.$get(this.apiConfig.pipelines(this.config));
    return response.data;
  }

  async getPipelines(): Promise<AstartePipeline[]> {
    const pipelineNames = await this.getPipelineNames();
    const pipelines = await Promise.all(pipelineNames.map(this.getPipeline));
    return pipelines;
  }

  async getPipeline(pipelineId: AstartePipeline['name']): Promise<AstartePipeline> {
    const response = await this.$get(this.apiConfig.pipelineSource({ ...this.config, pipelineId }));
    return new AstartePipeline(fromAstartePipelineDTO(response.data));
  }

  async getPipelineSource(pipelineId: any): Promise<any> {
    const response = await this.$get(this.apiConfig.pipelineSource({ ...this.config, pipelineId }));
    return response.data;
  }

  async registerPipeline(pipeline: AstartePipeline): Promise<void> {
    await this.$post(this.apiConfig.pipelines(this.config), toAstartePipelineDTO(pipeline));
  }

  async deletePipeline(pipelineId: any): Promise<void> {
    await this.$delete(this.apiConfig.pipelineSource({ ...this.config, pipelineId }));
  }

  async getBlocks(): Promise<AstarteBlock[]> {
    const staticBlocks = definitions.blocks as AstarteBlockDTO[];
    const response = await this.$get(this.apiConfig.blocks(this.config));
    const fetchedBlocks = response.data as AstarteBlockDTO[];
    const allBlocks = _.uniqBy(fetchedBlocks.concat(staticBlocks), 'name');
    return allBlocks.map((block: AstarteBlockDTO) => toAstarteBlock(block));
  }

  async registerBlock(block: AstarteCustomBlock): Promise<void> {
    const staticBlocksName = definitions.blocks.map((b) => b.name);
    if (staticBlocksName.includes(block.name)) {
      throw new Error("The block's name already exists");
    }
    await this.$post(this.apiConfig.blocks(this.config), block);
  }

  async getBlock(blockId: AstarteBlock['name']): Promise<AstarteBlock> {
    let blockDTO: AstarteBlockDTO;
    const staticBlocksName = definitions.blocks.map((block) => block.name);
    if (staticBlocksName.includes(blockId)) {
      blockDTO = definitions.blocks.find((block) => block.name === blockId) as AstarteBlockDTO;
    } else {
      const response = await this.$get(this.apiConfig.blockSource({ ...this.config, blockId }));
      blockDTO = response.data;
    }
    return toAstarteBlock(blockDTO);
  }

  async deleteBlock(blockId: AstarteBlock['name']): Promise<void> {
    const staticBlocksName = definitions.blocks.map((b) => b.name);
    if (staticBlocksName.includes(blockId)) {
      throw new Error('Cannot delete a native block');
    }
    await this.$delete(this.apiConfig.blockSource({ ...this.config, blockId }));
  }

  async getRealmManagementHealth(): Promise<any> {
    const response = await this.$get(this.apiConfig.realmManagementHealth(this.config));
    return response.data;
  }

  async getAppengineHealth(): Promise<any> {
    const response = await this.$get(this.apiConfig.appengineHealth(this.config));
    return response.data;
  }

  async getPairingHealth(): Promise<any> {
    const response = await this.$get(this.apiConfig.pairingHealth(this.config));
    return response.data;
  }

  async getFlowHealth(): Promise<any> {
    const response = await this.$get(this.apiConfig.flowHealth(this.config));
    return response.data;
  }

  private async $get(url: string): Promise<any> {
    return axios({
      method: 'get',
      url,
      headers: {
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8',
      },
    }).then((response) => response.data);
  }

  private async $post(url: string, data: any): Promise<any> {
    return axios({
      method: 'post',
      url,
      headers: {
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8',
      },
      data: {
        data,
      },
    }).then((response) => response.data);
  }

  private async $put(url: string, data: any): Promise<any> {
    return axios({
      method: 'put',
      url,
      headers: {
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8',
      },
      data: {
        data,
      },
    }).then((response) => response.data);
  }

  private async $patch(url: string, data: any): Promise<any> {
    return axios({
      method: 'patch',
      url,
      headers: {
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/merge-patch+json',
      },
      data: {
        data,
      },
    }).then((response) => response.data);
  }

  private async $delete(url: string): Promise<any> {
    return axios({
      method: 'delete',
      url,
      headers: {
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8',
      },
    }).then((response) => response.data);
  }

  private async openSocketConnection(): Promise<PhoenixSocket> {
    if (this.phoenixSocket) {
      return Promise.resolve(this.phoenixSocket);
    }

    const socketUrl = new URL(this.apiConfig.phoenixSocket(this.config));
    socketUrl.protocol = socketUrl.protocol === 'https:' ? 'wss:' : 'ws:';

    return new Promise((resolve) => {
      openNewSocketConnection(
        {
          socketUrl,
          realm: this.config.realm,
          token: this.token,
        },
        () => {
          this.dispatch('socketError');
        },
        () => {
          this.dispatch('socketClose');
        },
      ).then((socket) => {
        this.phoenixSocket = socket;
        resolve(socket);
      });
    });
  }

  async joinRoom(roomName: string): Promise<Channel> {
    const { phoenixSocket } = this;
    if (!phoenixSocket) {
      return new Promise((resolve) => {
        this.openSocketConnection().then(() => {
          resolve(this.joinRoom(roomName));
        });
      });
    }

    const channel = this.joinedChannels[roomName];
    if (channel) {
      return Promise.resolve(channel);
    }

    return new Promise((resolve) => {
      joinChannel(phoenixSocket, `rooms:${this.config.realm}:${roomName}`).then((joinedChannel) => {
        this.joinedChannels[roomName] = joinedChannel;
        resolve(joinedChannel);
      });
    });
  }

  async listenForEvents(
    roomName: string,
    eventHandler: (event: AstarteDeviceEvent) => void,
  ): Promise<void> {
    const channel = this.joinedChannels[roomName];
    if (!channel) {
      return Promise.reject(new Error("Can't listen for room events before joining it first"));
    }

    channel.on('new_event', (jsonEvent: any) => {
      const decodedEvent = decodeEvent(jsonEvent);

      if (decodedEvent) {
        eventHandler(decodedEvent);
      } else {
        throw new Error('Unrecognised event received');
      }
    });
    return Promise.resolve();
  }

  async registerVolatileTrigger(roomName: string, triggerPayload: Trigger): Promise<void> {
    const channel = this.joinedChannels[roomName];
    if (!channel) {
      return Promise.reject(new Error("Room not joined, couldn't register trigger"));
    }

    return registerTrigger(channel, triggerPayload);
  }

  async leaveRoom(roomName: string): Promise<void> {
    const channel = this.joinedChannels[roomName];
    if (!channel) {
      return Promise.reject(new Error("Can't leave a room without joining it first"));
    }

    return leaveChannel(channel).then(() => {
      delete this.joinedChannels[roomName];
    });
  }

  get joinedRooms(): any[] {
    const rooms: string[] = [];
    Object.keys(this.joinedChannels).forEach((roomName) => {
      rooms.push(roomName);
    });
    return rooms;
  }
}

export default AstarteClient;
