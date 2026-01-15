import axios from "axios";
import { reverse } from "named-urls";

const interfaceNames = {
  AVAILABLE_SENSORS: "org.astarte-platform.genericsensors.AvailableSensors",
  GEOLOCATION: "org.astarte-platform.genericsensors.Geolocation",
};

const storageKeys = {
  REALM: "realm",
  TOKEN: "token",
  ENDPOINT: "endpoint",
};

const endpoints = {
  device_alias: "devices-by-alias/:deviceAlias/",
  device_id: "devices/:deviceId?",
  interface_by_id: "devices/:deviceId/interfaces/:interfaceName/",
};

function getAPIUrl(endpointId, params = null) {
  const path = reverse(endpoints[endpointId], params);
  return getEndpoint() + "appengine/v1/" + getRealmName() + "/" + path;
}

function GET(url, params) {
  const headers = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${getAuthToken()}`,
  };
  return axios.get(url, { headers: headers, params: params });
}

// API Functions

function isDeviceUUID(value) {
  const expression = new RegExp(/[a-z]?[A-Z]?[0-9]?-?_?/i);
  return value.length === 22 && expression.test(value);
}

function getDeviceById(deviceId, params = {}) {
  const URL = getAPIUrl("device_id", { deviceId });
  return GET(URL, params);
}

function getDeviceByAlias(deviceAlias, params = {}) {
  const URL = getAPIUrl("device_alias", { deviceAlias });
  return GET(URL, params);
}

function getDevice(aliasOrId, params = {}) {
  return isDeviceUUID(aliasOrId)
    ? getDeviceById(aliasOrId, params)
    : getDeviceByAlias(aliasOrId, params);
}

function handleDeviceDataInterfaces(device) {
  const interfaces = Object.keys(device.introspection);
  const availableSensorsInterface = interfaces.find(
    (iface) => iface === interfaceNames.AVAILABLE_SENSORS,
  );
  const geolocationInterface = interfaces.find(
    (iface) => iface === interfaceNames.GEOLOCATION,
  );
  return {
    device,
    interfaces,
    availableSensorsInterface,
    geolocationInterface,
  };
}

export const getDeviceData = (deviceAliasOrId, params = {}) => {
  return getDevice(deviceAliasOrId, params)
    .then((response) => {
      return Promise.resolve(handleDeviceDataInterfaces(response.data.data));
    })
    .catch((err) => {
      return Promise.reject(err);
    });
};

export function getInterface(deviceId, interfaceName, params = {}) {
  const URL = getAPIUrl("interface_by_id", {
    deviceId,
    interfaceName,
  });
  return GET(URL, params).then((response) => response.data.data);
}

// LocalStorage Config

export function setAuthToken(token) {
  localStorage.setItem(storageKeys.TOKEN, token);
}

export function getAuthToken() {
  return localStorage.getItem(storageKeys.TOKEN) || "";
}

export function setRealmName(realmName) {
  localStorage.setItem(storageKeys.REALM, realmName);
}

export function getRealmName() {
  return localStorage.getItem(storageKeys.REALM) || "";
}

export function setEndpoint(endpoint) {
  localStorage.setItem(storageKeys.ENDPOINT, endpoint);
}

export function getEndpoint() {
  return localStorage.getItem(storageKeys.ENDPOINT) || "";
}

export function isMissingCredentials() {
  return !(getEndpoint() && getAuthToken() && getRealmName());
}
