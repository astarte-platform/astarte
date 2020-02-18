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
    let internalConfig = {};

    if (config.realm) {
      internalConfig.realm = config.realm;
    } else {
      throw Error("Missing parameter: realm");
    }

    if (config.realmManagementUrl) {
      internalConfig.realmManagementUrl = new URL(config.realmManagementUrl);
    }

    if (config.appengineUrl) {
      internalConfig.appengineUrl = new URL(config.appengineUrl);
    }

    this.config = internalConfig;

    if (config.token) {
      this.token = config.token;
    }

    // prettier-ignore
    let apiConfig = {
      auth:                  astarteAPIurl`${"realmManagementUrl"}/v1/${"realm"}/config/auth`,
      devices:               astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/devices`,
      detailedDevices:       astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/devices?details=true`,
      groups:                astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/groups`,
      groupDevices:          astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/groups/${"groupName"}/devices`,
      detailedGroupDevices:  astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/groups/${"groupName"}/devices?details=true`,
      deviceInGroup:         astarteAPIurl`${"appengineUrl"}/v1/${"realm"}/groups/${"groupName"}/devices/${"deviceId"}`
    };
    this.apiConfig = apiConfig;
  }

  getConfigAuth() {
    return this._get(this.apiConfig["auth"](this.config));
  }

  getDevices(details = false) {
    let endpointUri;
    if (details) {
      endpointUri = this.apiConfig["detailedDevices"];
    } else {
      endpointUri = this.apiConfig["devices"];
    }

    return this._get(endpointUri(this.config));
  }

  getGroupList() {
    return this._get(this.apiConfig["groups"](this.config));
  }

  createGroup(groupName, deviceList) {
    return this._post(this.apiConfig["groups"](this.config), {
      group_name: groupName,
      devices: deviceList
    });
  }

  getDevicesInGroup(groupName, details = false) {
    if (!groupName) {
      throw Error("Invalid group name");
    }

    let endpointUri;
    if (details) {
      endpointUri = this.apiConfig["detailedGroupDevices"];
    } else {
      endpointUri = this.apiConfig["groupDevices"];
    }

    return this._get(endpointUri({ ...this.config, groupName: groupName }));
  }

  removeDeviceFromGroup(groupName, deviceId) {
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

  _get(url) {
    return Request({
      method: "GET",
      uri: url,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      json: true
    });
  }

  _post(url, data) {
    return Request({
      method: "POST",
      uri: url,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      body: {
        data: data
      },
      json: true
    });
  }

  _delete(url) {
    return Request({
      method: "DELETE",
      uri: url,
      headers: {
        Authorization: `Bearer ${this.token}`
      },
      json: true
    });
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
