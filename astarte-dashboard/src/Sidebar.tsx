/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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

import React, { useMemo } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Nav, NavItem, NavLink } from 'react-bootstrap';

import { useAstarte } from './AstarteManager';
import { useConfig } from './ConfigManager';
import Icon from './components/Icon';
import useFetch from './hooks/useFetch';
import useInterval from './hooks/useInterval';

const SidebarApiStatus = () => {
  const config = useConfig();
  const astarte = useAstarte();
  const deviceRegistrationLimitFetcher = useFetch(astarte.client.getDeviceRegistrationLimit);
  const devicesStatsFetcher = useFetch(astarte.client.getDevicesStats);

  const healthFetcher = useFetch(() => {
    const apiChecks = [
      astarte.client.getAppengineHealth(),
      astarte.client.getRealmManagementHealth(),
      astarte.client.getPairingHealth(),
    ];
    if (config.features.flow) {
      apiChecks.push(astarte.client.getFlowHealth());
    }
    return Promise.all(apiChecks);
  });

  useInterval(deviceRegistrationLimitFetcher.refresh, 30000);
  useInterval(devicesStatsFetcher.refresh, 30000);
  useInterval(healthFetcher.refresh, 30000);

  const isApiHealthy = healthFetcher.status !== 'err';

  if (!astarte.isAuthenticated) {
    return null;
  }

  return (
    <NavItem className="nav-status pl-4">
      <div>
        <b>Realm</b>
      </div>
      <p>{astarte.realm}</p>
      <div>
        <b>Connected devices</b>
      </div>
      <p>
        {devicesStatsFetcher.value != null
          ? `${devicesStatsFetcher.value.connectedDevices} / ${devicesStatsFetcher.value.totalDevices}`
          : '-'}
      </p>
      <div>
        <b>Registered devices</b>
      </div>
      <p>
        {devicesStatsFetcher.value != null
          ? deviceRegistrationLimitFetcher.value != null
            ? `${devicesStatsFetcher.value.totalDevices} / ${deviceRegistrationLimitFetcher.value}`
            : devicesStatsFetcher.value.totalDevices
          : '-'}
      </p>
      <div>
        <b>API Status</b>
      </div>
      <p className="my-1">
        <Icon icon={isApiHealthy ? 'statusConnected' : 'statusDisconnected'} className="mr-2" />
        {isApiHealthy ? 'Up and running' : 'Degraded'}
      </p>
    </NavItem>
  );
};

interface SidebarAppInfoProps {
  appVersion: string;
}

const SidebarAppInfo = ({ appVersion }: SidebarAppInfoProps) => (
  <NavItem className="dashboard-version">
    <p>{`Astarte Dashboard v${appVersion}`}</p>
  </NavItem>
);

const SidebarBrand = () => (
  <Link to="/" className="nav-brand mb-3">
    <img alt="Astarte logo" src="/static/img/logo.svg" className="brand-logo" />
  </Link>
);

interface SidebarItemProps {
  icon: React.ComponentProps<typeof Icon>['icon'];
  label: string;
  link: string;
}

const SidebarItem = ({ icon, label, link }: SidebarItemProps) => {
  const location = useLocation();

  const isSelected = useMemo(() => {
    if (link === '/') {
      return location.pathname === '/' || location.pathname === '/home';
    }
    return location.pathname.startsWith(link);
  }, [link, location.pathname]);

  return (
    <NavLink as={Link} to={link} active={isSelected}>
      <Icon icon={icon} className="mr-2" />
      {label}
    </NavLink>
  );
};

const SidebarSeparator = () => (
  <NavItem>
    <hr />
  </NavItem>
);

interface Props {
  children: React.ReactNode;
}

const Sidebar = ({ children }: Props): React.ReactElement => (
  <Nav className="navbar-dark flex-nowrap vh-100 overflow-auto flex-column">{children}</Nav>
);

Sidebar.ApiStatus = SidebarApiStatus;
Sidebar.AppInfo = SidebarAppInfo;
Sidebar.Brand = SidebarBrand;
Sidebar.Item = SidebarItem;
Sidebar.Separator = SidebarSeparator;

export default Sidebar;
