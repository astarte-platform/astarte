import { reverse } from "named-urls";
import axios from "axios";

export const constant = {
  ID: "id",
  ALIAS: "alias",
  AVAILABLE_SENSORS: "AvailableSensors",
  VALUES: "Values",
  SAMPLING_RATE: "SamplingRate",
  REALM: "realm",
  TOKEN: "token",
  ENDPOINT: "endpoint",
};

const Endpoint = {
  device_alias: "devices-by-alias/:device_alias/",
  device_id: "devices/:id?",
  interface_by_alias: "devices/:device_alias/interfaces/:interface/",
  interface_by_id: "devices/:device_id/interfaces/:interface/",
  interface_id_path: "devices/:device_id/interfaces/:interface/:path/value",
  interface_alias_path:
    "devices/:device_alias/interfaces/:interface/:path/value",
};

function getAPIUrl(endPoint, params = null) {
  const path = reverse(Endpoint[endPoint], params);
  return getEndPoint() + "appengine/v1/" + getRealmName() + "/" + path;
}

function GET(url, params) {
  const headers = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${getAuthToken()}`,
  };
  return axios.get(url, { headers: headers, params: params });
}

// API Functions

function getDeviceById(id, params = {}) {
  const URL = getAPIUrl("device_id", { id: id });
  return GET(URL, params);
}

export const getDeviceDataById = (id, params = {}) => {
  return getDeviceById(id, params)
    .then((response) => {
      const data = response.data.data;
      const interfaces = Object.keys(data.introspection);
      const availableIndex = interfaces.findIndex(
        (key) => key.search(constant.AVAILABLE_SENSORS) > -1
      );
      const valueIndex = interfaces.findIndex(
        (key) => key.search(constant.VALUES) > -1
      );
      return Promise.resolve({ valueIndex, availableIndex, interfaces });
    })
    .catch((err) => {
      return Promise.reject(err);
    });
};

export const getDeviceDataByAlias = (alias, params = {}) => {
  return getDeviceByAlias(alias, params)
    .then((response) => {
      const data = response.data.data;
      const interfaces = Object.keys(data.introspection);
      const availableIndex = interfaces.findIndex(
        (key) => key.search(constant.AVAILABLE_SENSORS) > -1
      );
      const valueIndex = interfaces.findIndex(
        (key) => key.search(constant.VALUES) > -1
      );
      return Promise.resolve({ valueIndex, availableIndex, interfaces });
    })
    .catch((err) => {
      return Promise.reject(err);
    });
};

function getDeviceByAlias(alias, params = {}) {
  const URL = getAPIUrl("device_alias", { device_alias: alias });
  return GET(URL, params);
}

export function getInterfaceById(device_id, interface_id, params = {}) {
  const URL = getAPIUrl("interface_by_id", {
    device_id: device_id,
    interface: interface_id,
  });
  return GET(URL, params).then((response) => response.data.data);
}

export function getSensorValueById(device_id, interface_id, path, params = {}) {
  const URL = getAPIUrl("interface_id_path", {
    device_id: device_id,
    interface: interface_id,
    path: path,
  });
  return GET(URL, params);
}

export function getInterfaceByAlias(device_alias, interface_id, params = {}) {
  const URL = getAPIUrl("interface_by_id", {
    device_alias: device_alias,
    interface: interface_id,
  });
  return GET(URL, params).then((response) => response.data.data);
}

// LocalStorage Config

export function setAuthToken(token) {
  localStorage.setItem(constant.TOKEN, token);
}

export function getAuthToken() {
  return localStorage.getItem(constant.TOKEN) || undefined;
}

export function setRealmName(realm_name) {
  localStorage.setItem(constant.REALM, realm_name);
}

export function getRealmName() {
  return localStorage.getItem(constant.REALM) || undefined;
}

export function setEndPoint(endpoint) {
  localStorage.setItem(constant.ENDPOINT, endpoint);
}

export function getEndPoint() {
  return localStorage.getItem(constant.ENDPOINT) || undefined;
}

export function isMissingCredentials() {
  return !(getEndPoint() && getAuthToken() && getRealmName());
}
