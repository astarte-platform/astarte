// Copyright 2020-2021 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

class Astarte {
  constructor({ endpoint, realm, token, device, version = "v1" }) {
    this.token = token;
    this.endpoint = new URL(endpoint);
    this.realm = realm;
    this.device = device;
    this.version = version;
  }

  deviceURL = (realm, device) => `appengine/v1/${realm}/devices/${device}`;
  deviceInterfaceURL = (realm, device, interfaces) =>
    `appengine/v1/${realm}/devices/${device}/interfaces/${interfaces}/`;

  request(url, callback) {
    let xhr = new XMLHttpRequest();
    xhr.open("GET", new URL(url, this.endpoint));
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Authorization", `Bearer ${this.token}`);
    xhr.send();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === 4) {
        callback(JSON.parse(xhr.response));
      }
    };
    xhr.onerror = function () {
      alert("Request failed");
    };
  }

  getDevice(callback) {
    const url = this.deviceURL(this.realm, this.device);
    this.request(url, callback);
  }

  getInterface(interfaces, callback) {
    const url = this.deviceInterfaceURL(this.realm, this.device, interfaces);
    this.request(url, callback);
  }
}
