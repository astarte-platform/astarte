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

    if (config.pairingUrl) {
      internalConfig.pairingUrl = new URL(config.pairingUrl);
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
      registerDevice:        astarteAPIurl`${"pairingUrl"}/v1/${"realm"}/agent/devices`,
    };
    this.apiConfig = apiConfig;
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
