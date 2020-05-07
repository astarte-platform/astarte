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
import {
  Router,
  Switch,
  Route,
  Link,
  useParams,
  useRouteMatch
} from "react-router-dom";

import GroupsPage from "./GroupsPage.js";
import GroupDevicesPage from "./GroupDevicesPage.js";
import NewGroupPage from "./NewGroupPage.js";
import DevicesPage from "./DevicesPage.js";
import RegisterDevicePage from "./RegisterDevicePage.js";

export function getRouter(reactHistory, astarteClient, fallback) {

  const pageProps = {
      history: reactHistory,
      astarte: astarteClient
  }

  return (
    <Router history={reactHistory}>
      <Switch>
        <Route exact path="/devices">
          <DevicesPage {...pageProps} />
        </Route>
        <Route exact path="/devices/register">
          <RegisterDevicePage {...pageProps} />
        </Route>
        <Route exact path="/groups">
          <GroupsPage {...pageProps} />
        </Route>
        <Route exact path="/groups/new">
          <NewGroupPage {...pageProps} />
        </Route>
        <Route path="/groups/:groupName">
          <GroupDevicesSubPath {...pageProps} />
        </Route>
        <Route path="*">
          <NoMatch fallback={fallback} />
        </Route>
      </Switch>
    </Router>
  );
}

function GroupDevicesSubPath(props) {
  let { groupName } = useParams();

  return <GroupDevicesPage groupName={groupName} {...props} />;
}

function NoMatch(props) {
  let { path, url } = useRouteMatch();
  props.fallback(url);

  return <p>Redirecting...</p>;
}
