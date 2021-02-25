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

import React, { useCallback, useMemo } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Nav, NavItem, NavLink } from 'react-bootstrap';
import AstarteClient from 'astarte-client';

import useFetch from './hooks/useFetch';
import useInterval from './hooks/useInterval';

interface SidebarApiStatusProps {
  astarte: AstarteClient;
}

const SidebarApiStatus = ({ astarte }: SidebarApiStatusProps) => {
  const appEngineHealth = useFetch(astarte.getAppengineHealth);
  const realmManagementHealth = useFetch(astarte.getRealmManagementHealth);
  const pairingHealth = useFetch(astarte.getPairingHealth);
  const flowHealth = astarte.features.flow ? useFetch(astarte.getFlowHealth) : null;

  const refreshHealth = useCallback(() => {
    appEngineHealth.refresh();
    realmManagementHealth.refresh();
    pairingHealth.refresh();
    if (flowHealth) {
      flowHealth.refresh();
    }
  }, [appEngineHealth, realmManagementHealth, pairingHealth, flowHealth]);

  useInterval(refreshHealth, 30000);

  const isApiHealthy = [appEngineHealth, realmManagementHealth, pairingHealth, flowHealth].every(
    (apiHealth) => apiHealth == null || apiHealth.status !== 'err',
  );

  return (
    <NavItem className="nav-status pl-4">
      <div>
        <b>Realm</b>
      </div>
      <p>{astarte.realm}</p>
      <div>
        <b>API Status</b>
      </div>
      <p className="my-1">
        <i className={`fas fa-circle mr-2 ${isApiHealthy ? 'color-green' : 'color-red'}`} />
        {isApiHealthy ? 'Up and running' : 'Degraded'}
      </p>
    </NavItem>
  );
};

const SidebarBrand = () => (
  <Link to="/" className="nav-brand mb-3">
    <img alt="Astarte logo" src="/static/img/logo.svg" className="brand-logo" />
  </Link>
);

interface SidebarItemProps {
  icon: string;
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
  }, [location.pathname]);

  return (
    <NavLink as={Link} to={link} active={isSelected}>
      <i className={`fas fa-${icon} mr-2`} />
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
Sidebar.Brand = SidebarBrand;
Sidebar.Item = SidebarItem;
Sidebar.Separator = SidebarSeparator;

export default Sidebar;
