import axios from "axios";
import { reverse } from "named-urls";

const ENDPOINT = {
  device_alias: "devices-by-alias/:device_alias/",
  device_id: "devices/:id?",
  interface_by_alias: "devices/:device_alias/interfaces/:interface/",
  interface_by_id: "devices/:device_id/interfaces/:interface/",
  interface_id_path: "devices/:device_id/interfaces/:interface/:sensor_id/:key",
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
      Authorization: `Bearer ${this.token}`,
    };
  }

  getAPIUrl(endPoint, params) {
    const path = reverse(ENDPOINT[endPoint], params);
    return new URL(
      `/appengine/${this.version}/${this.realm}/${path}`,
      this.endpoint,
    );
  }

  GET(url, params) {
    return axios.get(url, { headers: this.getHeaders(), params: params });
  }

  PUT(url, params) {
    return axios.put(url, params, { headers: this.getHeaders() });
  }

  DELETE(url) {
    return axios.delete(url, { headers: this.getHeaders() });
  }

  isDeviceId(value) {
    const expression = new RegExp(/^[a-zA-Z0-9-_]{22}$/g);
    return expression.test(value);
  }

  getDeviceDataById(device, params = {}) {
    const URL = this.getAPIUrl("device_id", { id: device });
    return this.GET(URL, params)
      .then((response) => Promise.resolve(response.data.data))
      .catch((err) => Promise.reject(err));
  }

  getDeviceDataByAlias(alias, params = {}) {
    const URL = this.getAPIUrl("device_alias", { device_alias: alias });
    return this.GET(URL, params)
      .then((response) => Promise.resolve(response.data.data))
      .catch((err) => Promise.reject(err));
  }

  getSensorValueById(id, interfaces, sensor_id, key, params = {}) {
    const URL = this.getAPIUrl("interface_id_path", {
      device_id: id,
      interface: interfaces,
      sensor_id: sensor_id,
      key: key,
    });
    return this.GET(URL, params);
  }

  setSensorSamplingById(data) {
    const { id, interfaces, sensor_id, key, unset = false, params = {} } = data;
    const URL = this.getAPIUrl("interface_id_path", {
      device_id: id,
      interface: interfaces,
      sensor_id: sensor_id,
      key: key,
    });
    if (unset) {
      return this.DELETE(URL);
    }
    return this.PUT(URL, params);
  }

  getInterfaceById(device_id, interface_id, params = {}) {
    const URL = this.getAPIUrl("interface_by_id", {
      device_id: device_id,
      interface: interface_id,
    });
    return this.GET(URL, params).then((response) => response.data.data);
  }
}
