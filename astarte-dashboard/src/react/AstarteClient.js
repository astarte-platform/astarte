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

import Request from "request-promise";

export default class AstarteClient {
  constructor(config) {
    if (config.realm) {
      this.realm = config.realm;
    } else {
      throw Error("Missing parameter: realm");
    }

    if (config.token) {
      this.token = config.token;
    }

    if (config.realmManagementUrl) {
      this.realmManagementUrl = new URL(config.realmManagementUrl);
    }

    if (config.appengineUrl) {
      this.appengineUrl = new URL(config.appengineUrl);
    }
  }

  getConfigAuth() {
    if (!this.realmManagementUrl) {
      throw Error("Realm Management URL not configured");
    }

    let options = {
      method: "GET",
      uri: this.realmManagementUrl + `/${this.realm}/config/auth`,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      json: true
    };

    return Request(options);
  }

  getDevices(details = false) {
    if (!this.appengineUrl) {
      throw Error("AppEngine URL not configured");
    }

    let endpointUri = this.appengineUrl + `/${this.realm}/devices`;
    if (details) {
      endpointUri += "?details=true";
    }

    let options = {
      method: "GET",
      uri: endpointUri,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      json: true
    };

    return Request(options);
  }

  getGroupList() {
    if (!this.appengineUrl) {
      throw Error("AppEngine URL not configured");
    }

    let options = {
      method: "GET",
      uri: this.appengineUrl + `/${this.realm}/groups`,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      json: true
    };

    return Request(options);
  }

  createGroup(groupName, deviceList) {
    if (!this.appengineUrl) {
      throw Error("AppEngine URL not configured");
    }

    let options = {
      method: "POST",
      uri: this.appengineUrl + `/${this.realm}/groups`,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      body: {
        data: {
          group_name: groupName,
          devices: deviceList
        }
      },
      json: true
    };

    return Request(options);
  }

  getDevicesInGroup(groupName, details = false) {
    if (!this.appengineUrl) {
      throw Error("AppEngine URL not configured");
    }

    if (!groupName) {
      throw Error("Invalid group name");
    }

    let endpointUri =
      this.appengineUrl + `/${this.realm}/groups/${groupName}/devices`;
    if (details) {
      endpointUri += "?details=true";
    }

    let options = {
      method: "GET",
      uri: endpointUri,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      json: true
    };

    return Request(options);
  }
}
