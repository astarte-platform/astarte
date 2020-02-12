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
const { Socket } = require("phoenix");

export default class AstarteClient {
  constructor(config) {
    let internalConfig = {};

    if (config.realm) {
      internalConfig.realm = config.realm;
    } else {
      throw Error("Missing parameter: realm");
    }

    this.secureConnection = config.secureConnection || false;

    if (config.realmManagementUrl) {
      internalConfig.realmManagementUrl = new URL(config.realmManagementUrl);
    }

    if (config.appengineUrl) {
      internalConfig.appengineUrl = new URL(config.appengineUrl);
    }

    if (config.pairingUrl) {
      internalConfig.pairingUrl = new URL(config.pairingUrl);
    }

    if (config.flowUrl) {
      internalConfig.flowUrl = new URL(config.flowUrl);
    }

    if (config.onSocketError) {
      this.onSocketError = config.onSocketError;
    }

    if (config.onSocketClose) {
      this.onSocketClose = config.onSocketClose;
    }

    this.config = internalConfig;

    if (config.token) {
      this.token = config.token;
    }

    // prettier-ignore
    let apiConfig = {
      auth:                  astarteAPIurl`${"realmManagementUrl"}/v1/${"realm"}/config/auth`,
      devicesStats:          astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/stats/devices`,
      devices:               astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/devices`,
      groups:                astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/groups`,
      groupDevices:          astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/groups/${"groupName"}/devices`,
      deviceInGroup:         astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/groups/${"groupName"}/devices/${"deviceId"}`,
      phoenixSocket:         astarteAPIurl`${"appengineUrl"}/v1/socket`,
      registerDevice:        astarteAPIurl`${"pairingUrl"}/v1/${"realm"}/agent/devices`,
      flows:                 astarteAPIurl`${"flowUrl"}/v1/${"realm"}/flows`,
      flowInstance:          astarteAPIurl`${"flowUrl"}/v1/${"realm"}/flows/${"instanceName"}`,
      pipelines:             astarteAPIurl`${"flowUrl"}/v1/${"realm"}/pipelines`,
      pipelineSource:        astarteAPIurl`${"flowUrl"}/v1/${"realm"}/pipelines/${"pipelineId"}`,
    };
    this.apiConfig = apiConfig;

    this.phoenixSocket = null;
    this.joinedChannels = {};
  }

  getConfigAuth() {
    return this._get(this.apiConfig["auth"](this.config));
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

  getDevicesInGroup(params) {
    let { groupName, details } = params;
    let endpointUri = new URL(
      this.apiConfig["groupDevices"]({ ...this.config, groupName: groupName })
    );

    if (!groupName) {
      throw Error("Invalid group name");
    }

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

  registerDevice(params) {
    const { deviceId } = params;
    return this._post(this.apiConfig["registerDevice"](this.config), {
      hw_id: deviceId
    });
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

    if (!this.config.appengineUrl) {
      return Promise.reject("No AppEngine API URL configured");
    }

    const socketUrl = new URL(this.apiConfig.phoenixSocket(this.config));
    socketUrl.protocol = (this.secureConnection ? "wss" : "ws")

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

function astarteAPIurl(strings, ...keys) {
  return function(...values) {
    let dict = values[values.length - 1] || {};
    let result = [strings[0]];
    keys.forEach(function(key, i) {
      let value = Number.isInteger(key) ? values[key] : dict[key];
      result.push(value, strings[i + 1]);
    });
    return result.join("");
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
