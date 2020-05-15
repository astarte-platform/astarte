import { reverse } from "named-urls";
import axios from "axios";

const { Socket } = require("phoenix");

const ENDPOINT = {
  device_alias: "devices-by-alias/:device_alias/",
  device_id: "devices/:id?",
  interface_by_alias: "devices/:device_alias/interfaces/:interface/",
  interface_by_id: "devices/:device_id/interfaces/:interface/",
  interface_id_path: "devices/:device_id/interfaces/:interface/:sensor_id/:key"
};

export default class ApiHandler {
  constructor({ endpoint, realm, token, version = "v1" }) {
    this.token = token;
    this.endpoint = new URL(endpoint);
    this.realm = realm;
    this.version = version;
    this.socket = null;
  }

  getDevice(device) {
    if (this.isDeviceId(device)) {
      return this.getDeviceDataById(device);
    } else {
      return this.getDeviceDataByAlias(device);
    }
  }

  getHeaders() {
    return {
      "Content-Type": "application/json",
      Authorization: `Bearer ${this.token}`
    };
  }

  getAPIUrl(endPoint, params) {
    const path = reverse(ENDPOINT[endPoint], params);
    return new URL(
      `/appengine/${this.version}/${this.realm}/${path}`,
      this.endpoint
    );
  }

  getWSUrl() {
    const astarteChannelUrl = new URL(
      `/appengine/${this.version}/socket`,
      this.endpoint
    );
    astarteChannelUrl.protocol = "wss:";
    return astarteChannelUrl;
  }

  GET(url, params) {
    return axios.get(url, { headers: this.getHeaders(), params: params });
  }

  PUT(url, params) {
    return axios.put(url, params, { headers: this.getHeaders() });
  }

  isDeviceId(value) {
    const expression = new RegExp(/^[a-zA-Z0-9-_]{22}$/g);
    return expression.test(value);
  }

  getDeviceDataById(device, params = {}) {
    const URL = this.getAPIUrl("device_id", { id: device });
    return this.GET(URL, params)
      .then(response => Promise.resolve(response.data.data))
      .catch(err => Promise.reject(err));
  }

  getDeviceDataByAlias(alias, params = {}) {
    const URL = this.getAPIUrl("device_alias", { device_alias: alias });
    return this.GET(URL, params)
      .then(response => Promise.resolve(response.data.data))
      .catch(err => Promise.reject(err));
  }

  getSensorValueById(id, interfaces, sensor_id, key, params = {}) {
    const URL = this.getAPIUrl("interface_id_path", {
      device_id: id,
      interface: interfaces,
      sensor_id: sensor_id,
      key: key
    });
    return this.GET(URL, params);
  }

  getInterfaceById(device_id, interface_id, params = {}) {
    const URL = this.getAPIUrl("interface_by_id", {
      device_id: device_id,
      interface: interface_id
    });
    return this.GET(URL, params).then(response => response.data.data);
  }

  connectSocket(params) {
    const {
      device,
      interfaceName,
      onInComingData,
      onOpenConnection = () => {},
      onCloseConnection = () => {},
      onErrorConnection = () => {}
    } = params;
    const socketUrl = this.getWSUrl();
    const socketParams = {
      params: {
        realm: this.realm,
        token: this.token
      }
    };
    const phoenixSocket = new Socket(socketUrl, socketParams);
    phoenixSocket.onOpen(onOpenConnection);
    phoenixSocket.onError(onErrorConnection);
    phoenixSocket.onClose(onCloseConnection);
    phoenixSocket.onMessage(onInComingData);
    phoenixSocket.connect();

    const room_name = Math.random()
      .toString(36)
      .substring(7);
    const channel = phoenixSocket.channel(
      `rooms:${this.realm}:${device}_${room_name}`,
      { token: this.token }
    );
    channel.join().receive("ok", response => {
      channel.push("watch", this.getConnectionTriggerPayload(device));
      channel.push("watch", this.getDisconnectionTriggerPayload(device));
      channel.push(
        "watch",
        this.getValueTriggerPayload({
          device,
          interfaceName
        })
      );
    });
    this.socket = phoenixSocket;
  }

  disconnectSocket() {
    this.socket.disconnect();
  }

  getConnectionTriggerPayload(device) {
    return {
      name: `connectiontrigger-${device}`,
      device_id: device,
      simple_trigger: {
        type: "device_trigger",
        on: "device_connected",
        device_id: device
      }
    };
  }

  getDisconnectionTriggerPayload(device) {
    return {
      name: `disconnectiontrigger-${device}`,
      device_id: device,
      simple_trigger: {
        type: "device_trigger",
        on: "device_disconnected",
        device_id: device
      }
    };
  }

  getValueTriggerPayload(params) {
    const {
      device,
      interfaceName,
      value_match_operator = "*",
      known_value = 0
    } = params;
    return {
      name: `valueTrigger-${device}`,
      device_id: device,
      simple_trigger: {
        type: "data_trigger",
        on: "incoming_data",
        interface_name: interfaceName,
        interface_major: 0,
        match_path: "/*",
        known_value: known_value,
        value_match_operator: value_match_operator
      }
    };
  }
}
