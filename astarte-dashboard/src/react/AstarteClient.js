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

import axios from "axios";
import jwt from "jsonwebtoken";
const { Socket } = require("phoenix");

import Block from "./models/Block";

class AstarteClient {
  constructor(config) {
    let internalConfig = {};

    internalConfig.realm = config.realm || "";
    this.token = config.token || "";

    if (config.onSocketError) {
      this.onSocketError = config.onSocketError;
    }

    if (config.onSocketClose) {
      this.onSocketClose = config.onSocketClose;
    }

    internalConfig.enableFlowPreview = config.enableFlowPreview || false;
    this.config = internalConfig;

    // prettier-ignore
    let apiConfig = {
      realmManagementHealth: astarteAPIurl`${ config.realmManagementUrl }health`,
      auth:                  astarteAPIurl`${ config.realmManagementUrl }v1/${"realm"}/config/auth`,
      interfaces:            astarteAPIurl`${ config.realmManagementUrl }v1/${"realm"}/interfaces`,
      interfaceMajors:       astarteAPIurl`${ config.realmManagementUrl }v1/${"realm"}/interfaces/${"interfaceName"}`,
      interfaceData:         astarteAPIurl`${ config.realmManagementUrl }v1/${"realm"}/interfaces/${"interfaceName"}/${"interfaceMajor"}`,
      triggers:              astarteAPIurl`${ config.realmManagementUrl }v1/${"realm"}/triggers`,
      appengineHealth:       astarteAPIurl`${ config.appengineUrl }health`,
      devicesStats:          astarteAPIurl`${ config.appengineUrl }v1/${"realm"}/stats/devices`,
      devices:               astarteAPIurl`${ config.appengineUrl }v1/${"realm"}/devices`,
      deviceInfo:            astarteAPIurl`${ config.appengineUrl }v1/${"realm"}/devices/${"deviceId"}`,
      deviceData:            astarteAPIurl`${ config.appengineUrl }v1/${"realm"}/devices/${"deviceId"}/interfaces/${"interfaceName"}`,
      groups:                astarteAPIurl`${ config.appengineUrl }v1/${"realm"}/groups`,
      groupDevices:          astarteAPIurl`${ config.appengineUrl }v1/${"realm"}/groups/${"groupName"}/devices`,
      deviceInGroup:         astarteAPIurl`${ config.appengineUrl }v1/${"realm"}/groups/${"groupName"}/devices/${"deviceId"}`,
      phoenixSocket:         astarteAPIurl`${ config.appengineUrl }v1/socket`,
      pairingHealth:         astarteAPIurl`${ config.pairingUrl }health`,
      registerDevice:        astarteAPIurl`${ config.pairingUrl }v1/${"realm"}/agent/devices`,
      flowHealth:            astarteAPIurl`${ config.flowUrl }health`,
      flows:                 astarteAPIurl`${ config.flowUrl }v1/${"realm"}/flows`,
      flowInstance:          astarteAPIurl`${ config.flowUrl }v1/${"realm"}/flows/${"instanceName"}`,
      pipelines:             astarteAPIurl`${ config.flowUrl }v1/${"realm"}/pipelines`,
      pipelineSource:        astarteAPIurl`${ config.flowUrl }v1/${"realm"}/pipelines/${"pipelineId"}`,
      blocks:                astarteAPIurl`${ config.flowUrl }v1/${"realm"}/blocks`,
      blockSource:           astarteAPIurl`${ config.flowUrl }v1/${"realm"}/blocks/${"blockId"}`,
    };
    this.apiConfig = apiConfig;

    this.phoenixSocket = null;
    this.joinedChannels = {};
    this.listeners = {};
  }

  addListener(eventName, callback) {
    if (!this.listeners[eventName]) {
      this.listeners[eventName] = [];
    }

    this.listeners[eventName].push(callback);
  }

  removeListener(eventName, callback) {
    const previousListeners = this.listeners[eventName];
    if (previousListeners) {
      this.listeners[eventName] = previousListeners.filter((listener) => listener !== callback);
    }
  }

  dispatch(eventName) {
    const listeners = this.listeners[eventName];
    if (listeners) {
      listeners.forEach((listener) => listener());
    }
  }

  setCredentials({ realm, token }) {
    this.config.realm = realm || "";
    this.token = token || "";

    this.dispatch('credentialsChange');
  }

  getConfigAuth() {
    return this._get(this.apiConfig["auth"](this.config));
  }

  updateConfigAuth(publicKey) {
    return this._put(this.apiConfig["auth"](this.config), {
      "jwt_public_key_pem": publicKey
    });
  }

  getInterfaceNames() {
    return this._get(this.apiConfig["interfaces"](this.config));
  }

  getInterfaceMajors(interfaceName) {
    return this._get(this.apiConfig["interfaceMajors"]({ ...this.config, interfaceName: interfaceName }));
  }

  getInterface({ interfaceName, interfaceMajor }) {
    return this._get(this.apiConfig["interfaceData"]({
      interfaceName: interfaceName,
      interfaceMajor: interfaceMajor,
      ...this.config
    }));
  }

  getTriggerNames() {
    return this._get(this.apiConfig["triggers"](this.config));
  }

  getDevicesStats() {
    return this._get(this.apiConfig["devicesStats"](this.config));
  }

  getDevices(params) {
    let endpointUri = new URL(this.apiConfig["devices"](this.config));
    let { details, limit, from } = params;
    let query = {};

    if (details) {
      query.details = true;
    }

    if (limit) {
      query.limit = limit;
    }

    if (from) {
      query.from_token = from;
    }

    if (query) {
      endpointUri.search = new URLSearchParams(query);
    }

    return this._get(endpointUri);
  }

  getDeviceInfo(deviceId) {
    return this._get(this.apiConfig["deviceInfo"]({ deviceId: deviceId, ...this.config }));
  }

  getDeviceData({ deviceId, interfaceName, interfaceMajor }) {
    return this._get(this.apiConfig["deviceData"]({
      deviceId: deviceId,
      interfaceName: interfaceName,
      ...this.config
    }));
  }

  getGroupList() {
    return this._get(this.apiConfig["groups"](this.config));
  }

  createGroup(params) {
    const { groupName, deviceList } = params;
    return this._post(this.apiConfig["groups"](this.config), {
      group_name: groupName,
      devices: deviceList
    });
  }

  getDevicesInGroup({ groupName, details }) {
    if (!groupName) {
      throw Error("Invalid group name");
    }

    /* Double encoding to preserve the URL format when groupName contains % and / */
    const encodedGroupName = encodeURIComponent(encodeURIComponent(groupName));
    const endpointUri = new URL(
      this.apiConfig["groupDevices"]({ ...this.config, groupName: encodedGroupName })
    );

    if (details) {
      endpointUri.search = new URLSearchParams({ details: true });
    }

    return this._get(endpointUri);
  }

  removeDeviceFromGroup(params) {
    let { groupName, deviceId } = params;

    if (!groupName) {
      throw Error("Invalid group name");
    }

    if (!deviceId) {
      throw Error("Invalid device ID");
    }

    return this._delete(
      this.apiConfig["deviceInGroup"]({
        ...this.config,
        groupName: groupName,
        deviceId: deviceId
      })
    );
  }

  registerDevice({ deviceId, introspection }) {
    let requestBody = {
      hw_id: deviceId
    };

    if (introspection) {
      let encodedintrospection = {};

      for (const [key, interfaceId] of introspection) {
        encodedintrospection[key] = {
          major: interfaceId.major,
          minor: interfaceId.minor
        }
      }

      requestBody.initial_introspection = encodedintrospection;
    }

    return this._post(this.apiConfig["registerDevice"](this.config), requestBody);
  }

  getFlowInstances() {
    return this._get(this.apiConfig["flows"](this.config));
  }

  getFlowDetails(flowName) {
    return this._get(
      this.apiConfig["flowInstance"]({ ...this.config, instanceName: flowName })
    );
  }

  createNewFlowInstance(pipelineConfig) {
    return this._post(this.apiConfig["flows"](this.config), pipelineConfig);
  }

  deleteFlowInstance(flowName) {
    return this._delete(
      this.apiConfig["flowInstance"]({ ...this.config, instanceName: flowName })
    );
  }

  getPipelineDefinitions() {
    return this._get(
      this.apiConfig["pipelines"](this.config)
    );
  }

  registerPipeline(pipeline) {
    return this._post(this.apiConfig["pipelines"](this.config), pipeline);
  }

  getPipelineInputConfig(pipelineId) {
    return this._get(
      this.apiConfig["pipelineSource"]({ ...this.config, pipelineId: pipelineId })
    );
  }

  getPipelineSource(pipelineId) {
    return this._get(this.apiConfig["pipelineSource"]({...this.config, pipelineId: pipelineId}));
  }

  deletePipeline(pipelineId) {
    return this._delete(this.apiConfig["pipelineSource"]({...this.config, pipelineId: pipelineId}));
  }

  getBlocks() {
    return this._get(this.apiConfig["blocks"](this.config)).then(response =>
      response.data.map(block => new Block(block))
    );
  }

  registerBlock(block) {
    return this._post(this.apiConfig["blocks"](this.config), block);
  }

  getBlock(blockId) {
    return this._get(
      this.apiConfig["blockSource"]({ ...this.config, blockId })
    ).then(response => new Block(response.data));
  }

  deleteBlock(blockId) {
    return this._delete(
      this.apiConfig["blockSource"]({ ...this.config, blockId })
    );
  }

  getRealmManagementHealth() {
    return this._get(this.apiConfig["realmManagementHealth"](this.config));
  }

  getAppengineHealth() {
    return this._get(this.apiConfig["appengineHealth"](this.config));
  }

  getPairingHealth() {
    return this._get(this.apiConfig["pairingHealth"](this.config));
  }

  getFlowHealth() {
    return this._get(this.apiConfig["flowHealth"](this.config));
  }

  _get(url) {
    return axios({
      method: "get",
      url: url,
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8'
      }
    })
      .then((response) => response.data);
  }

  _post(url, data) {
    return axios({
      method: "post",
      url: url,
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8'
      },
      data: {
        data: data
      }
    })
      .then((response) => response.data);
  }

  _put(url, data) {
    return axios({
      method: "put",
      url: url,
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8'
      },
      data: {
        data: data
      }
    })
      .then((response) => response.data);
  }

  _delete(url) {
    return axios({
      method: "delete",
      url: url,
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json;charset=UTF-8'
      }
    })
      .then((response) => response.data);
  }

  openSocketConnection() {
    if (this.phoenixSocket) {
      return Promise.resolve(this.phoenixSocket);
    }

    const socketUrl = new URL(this.apiConfig.phoenixSocket(this.config));
    socketUrl.protocol = (socketUrl.protocol === "https:" ? "wss:" : "ws:")

    return new Promise((resolve, reject) => {
      openNewSocketConnection({
        socketUrl: socketUrl,
        realm: this.config.realm,
        token: this.token
      },
      () => { this.onSocketError },
      () => { this.onSocketClose })
        .then((socket) => {
          this.phoenixSocket = socket;
          resolve(socket);
        })
    });
  }

  joinRoom(roomName) {
    if (!this.phoenixSocket) {
      return new Promise((resolve, reject) => {
        this.openSocketConnection()
        .then(() => { resolve(this.joinRoom(roomName))});
      });
    }

    let channel = this.joinedChannels[roomName];
    if (channel) {
      return Promise.resolve(channel);
    }

    return new Promise((resolve, reject) => {
      joinChannel(this.phoenixSocket, `rooms:${this.config.realm}:${roomName}`)
        .then((channel) => {
          this.joinedChannels[roomName] = channel;
          resolve(true);
        })
    });
  }

  listenForEvents(roomName, eventHandler) {
    let channel = this.joinedChannels[roomName];
    if (!channel) {
      return Promise.reject("Can't listen for room events before joining it first");
    }

    channel.on("new_event", eventHandler);
  }

  registerVolatileTrigger(roomName, triggerPayload) {
    let channel = this.joinedChannels[roomName];
    if (!channel) {
      return Promise.reject("Room not joined, couldn't register trigger");
    }

    return registerTrigger(channel, triggerPayload);
  }

  leaveRoom(roomName) {
    let channel = this.joinedChannels[roomName];
    if (!channel) {
      return Promise.reject("Can't leave a room without joining it first");
    }

    return leaveChannel(channel)
      .then(() => {
        delete this.joinedChannels[roomName];
      });
  }

  joinedRooms() {
    let rooms = [];
    for (let roomName in this.joinedChannels) {
      rooms.push(roomName);
    }
    return rooms;
  }
}

function astarteAPIurl(strings, baseUrl, ...keys) {
  return function(...values) {
    let dict = values[values.length - 1] || {};
    let result = [strings[1]];
    keys.forEach(function(key, i) {
      let value = Number.isInteger(key) ? values[key] : dict[key];
      result.push(value, strings[i + 2]);
    });
    return new URL(result.join(""), baseUrl);
  };
}


// Wrap phoenix lib calls in promise for async handling

function openNewSocketConnection(connectionParams, onErrorHanlder, onCloseHandler) {
  const { socketUrl, realm, token } = connectionParams;

  return new Promise((resolve, reject) => {
    const phoenixSocket = new Socket(socketUrl, {
      params: {
        realm: realm,
        token: token
      }
    });
    phoenixSocket.onError((e) => onErrorHanlder(e));
    phoenixSocket.onClose((e) => onCloseHandler(e));
    phoenixSocket.onOpen(() => { resolve(phoenixSocket) });
    phoenixSocket.connect();
  });
}

function joinChannel(phoenixSocket, channelString) {
  return new Promise((resolve, reject) => {
    const channel = phoenixSocket.channel(channelString, {});
    channel
      .join()
      .receive("ok", (resp) => { resolve(channel) })
      .receive("error", (err) => { reject(err) });
  });
}

function leaveChannel(channel) {
  return new Promise((resolve, reject) => {
    channel
      .leave()
      .receive("ok", (resp) => { resolve(channel) })
      .receive("error", (err) => { reject(err) });
  });
}

function registerTrigger(channel, triggerPayload) {
  return new Promise((resolve, reject) => {
    channel
      .push("watch", triggerPayload)
      .receive("ok", (resp) => { resolve(channel) })
      .receive("error", (err) => { reject(err) });
  });
}

function isValidRealmName(name) {
  return RegExp('^[a-z][a-z0-9]{0,47}$').test(name) &&
        !name.startsWith("astarte") &&
        !name.startsWith("system");
}

function isTokenExpired(decodedTokenObject) {
  if (decodedTokenObject.exp) {
    const posix = Number.parseInt(decodedTokenObject.exp);
    const expiry = new Date(posix * 1000);
    const now = new Date();

    return (expiry <= now);
  } else {
    return false;
  }
}

function hasAstarteClaims(decodedTokenObject) {
  // AppEngine API
  if ("a_aea" in decodedTokenObject) {
    return true;
  }

  // Realm Management API
  if ("a_rma" in decodedTokenObject) {
    return true;
  }

  // Pairing API
  if ("a_pa" in decodedTokenObject) {
    return true;
  }

  // Astarte Channels
  if ("a_ch" in decodedTokenObject) {
    return true;
  }

  return false;
}

function validateAstarteToken(token) {
  const decoded = jwt.decode(token, {complete: true});

  let status;

  if (decoded) {
    if (isTokenExpired(decoded.payload)) {
      status = "expired";

    } else if (!hasAstarteClaims(decoded.payload)) {
      status = "notAnAstarteToken";

    } else {
      status = "valid";
    }

  } else {
    status = "invalid";
  }

  return status;
}

export default AstarteClient;
export { isValidRealmName, validateAstarteToken };
