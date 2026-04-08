import axios from "axios";
import { reverse } from "named-urls";

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

function handleDeviceDataInterfaces(data) {
  const interfaces = Object.keys(data.introspection);
  const availableSensorsInterface = interfaces.find(
    (key) => key.search(constant.AVAILABLE_SENSORS) > -1,
  );
  const valuesInterface = interfaces.find(
    (key) => key.search(constant.VALUES) > -1,
  );
  const samplingRateInterface = interfaces.find(
    (key) => key.search(constant.SAMPLING_RATE) > -1,
  );
  return {
    interfaces,
    availableSensorsInterface,
    valuesInterface,
    samplingRateInterface,
    data,
  };
}

export const getDeviceDataById = (id, params = {}) => {
  return getDeviceById(id, params)
    .then((response) => {
      return Promise.resolve(handleDeviceDataInterfaces(response.data.data));
    })
    .catch((err) => {
      return Promise.reject(err);
    });
};

function getDeviceByAlias(alias, params = {}) {
  const URL = getAPIUrl("device_alias", { device_alias: alias });
  return GET(URL, params);
}

export const getDeviceDataByAlias = (alias, params = {}) => {
  return getDeviceByAlias(alias, params)
    .then((response) => {
      return Promise.resolve(handleDeviceDataInterfaces(response.data.data));
    })
    .catch((err) => {
      return Promise.reject(err);
    });
};

export function getInterfaceById(device_id, interface_id, params = {}) {
  const URL = getAPIUrl("interface_by_id", {
    device_id: device_id,
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
