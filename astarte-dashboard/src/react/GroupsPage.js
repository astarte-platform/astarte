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

import React from "react";
import { Link } from "react-router-dom";
import Spinner from "react-bootstrap/Spinner";

import AstarteClient from "./AstarteClient.js";
import Card from "./ui/Card.js";

export default class GroupsPage extends React.Component {
  constructor(props) {
    super(props);

    let config = JSON.parse(localStorage.session).api_config;
    let protocol = config.secure_connection ? "https://" : "http://";
    let astarteConfig = {
      realm: config.realm,
      token: config.token,
      realmManagementUrl: protocol + config.realm_management_url,
      appengineUrl: protocol + config.appengine_url
    };

    this.state = {
      phase: "loading"
    };

    this.handleGroupsRequest = this.handleGroupsRequest.bind(this);
    this.handleGroupsError = this.handleGroupsError.bind(this);

    let astarte = new AstarteClient(astarteConfig);
    astarte
      .getGroupList()
      .then(this.handleGroupsRequest)
      .catch(this.handleGroupsError);
  }

  handleGroupsRequest(data) {
    this.setState({
      phase: "ok",
      groups: data.data
    });
  }

  handleGroupsError(err) {
    this.setState({
      phase: "err",
      error: err
    });
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        innerHTML = (
          <ul>
            {this.state.groups.map((value, index) => {
              return (
                <li key={index}>
                  <Link to={`/groups/${value}`}>{value}</Link>
                </li>
              );
            })}
          </ul>
        );
        break;

      case "err":
        innerHTML = <p>Couldn't load groups</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return <Card title="Groups">{innerHTML}</Card>;
  }
}
