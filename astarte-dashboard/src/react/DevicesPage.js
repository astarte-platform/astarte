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
  Container,
  Row,
  Col,
  Button,
  OverlayTrigger,
  Pagination,
  Spinner,
  Table,
  Tooltip
} from "react-bootstrap";

import AstarteClient from "./AstarteClient.js";
import Device from "./astarte/Device.js";
import SingleCardPage from "./ui/SingleCardPage.js";
import { Link } from "react-router-dom";

const DEVICES_PER_PAGE = 20;
const MAX_SHOWN_PAGES = 10;

export default class DevicesPage extends React.Component {
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
    this.astarte = new AstarteClient(astarteConfig);

    this.handleStatsRequest = this.handleStatsRequest.bind(this);
    this.handleDevicesRequest = this.handleDevicesRequest.bind(this);
    this.cachePage = this.cachePage.bind(this);
    this.loadPage = this.loadPage.bind(this);
    this.handleError = this.handleError.bind(this);

    this.state = {
      phase: "loading",
      devices: [],
      totalDevices: null
    };

    this.astarte
      .getDevicesStats()
      .then(this.handleStatsRequest)
      .catch(this.handleError);
  }

  handleStatsRequest(response) {
    const totalDevices = response.data.total_devices;

    if (totalDevices > 0) {
      this.setState({
        totalDevices: totalDevices,
        activePage: 0,
        maxPage: Math.ceil(totalDevices / DEVICES_PER_PAGE),
        cachedPages: []
      });

      this.cachePage(0);
    } else {
      this.setState({
        phase: "ok",
        totalDevices: 0
      });
    }

    return null; // handle promise async
  }

  cachePage(pageIndex) {
    if (pageIndex == 0) {
      this.astarte
        .getDevices({
          details: true,
          limit: DEVICES_PER_PAGE
        })
        .then(response => {
          return this.handleDevicesRequest(pageIndex, response);
        })
        .catch(console.log);
    } else {
      const token = this.state.cachedPages[pageIndex - 1].token;

      if (token) {
        this.astarte
          .getDevices({
            details: true,
            from: token,
            limit: DEVICES_PER_PAGE
          })
          .then(response => {
            return this.handleDevicesRequest(pageIndex, response);
          })
          .catch(console.log);
      }
    }

    return null; // handle promise async
  }

  handleDevicesRequest(pageIndex, response) {
    let token = new URLSearchParams(response.links.next).get("from_token");

    let deviceList = response.data.map(value => {
      return Device.fromObject(value);
    });

    let cachedPages = this.state.cachedPages;
    cachedPages[pageIndex] = {
      devices: deviceList,
      token: token
    };

    this.setState({
      cachedPages: cachedPages
    });

    const activePage = this.state.activePage;
    if (pageIndex == this.state.activePage) {
      this.setState({
        phase: "ok",
        activePage: pageIndex
      });
    }

    const pagesToCache = activePage + MAX_SHOWN_PAGES + 1;
    if (pageIndex < pagesToCache) {
      this.cachePage(pageIndex + 1);
    }

    return null; // handle promise async
  }

  loadPage(pageIndex) {
    const cachedPages = this.state.cachedPages;

    if (!cachedPages[pageIndex]) {
      console.log("Loading a page not ready to be shown");
      return;
    }

    this.setState({
      phase: "ok",
      activePage: pageIndex
    });

    const lastCachedPage = cachedPages.length - 1;
    const pagesToCache = pageIndex + MAX_SHOWN_PAGES + 1;
    if (lastCachedPage < pagesToCache) {
      this.cachePage(lastCachedPage + 1);
    }
  }

  handleError(err) {
    this.setState({
      phase: "err",
      error: err
    });
    console.log(err);
  }

  render() {
    let innerHTML;

    switch (this.state.phase) {
      case "ok":
        if (this.state.totalDevices) {
          const { activePage, cachedPages } = this.state;
          const viewAblePages = cachedPages.length;
          const devices = cachedPages[activePage].devices;

          innerHTML = (
            <>
              <Link className="float-right mb-2" to={`/devices/register`}>
                Register a new device
              </Link>
              <DeviceTable deviceList={devices} />
              <Container fluid>
                <Row>
                  <Col></Col>
                  <Col>
                    <TablePagination
                      active={activePage}
                      max={viewAblePages}
                      onPageChange={this.loadPage}
                    />
                  </Col>
                  <Col></Col>
                </Row>
              </Container>
            </>
          );
        } else {
          innerHTML = <p>No registered devices</p>;
        }
        break;

      case "err":
        innerHTML = <p>Couldn't load the device list</p>;
        break;

      default:
        innerHTML = <Spinner animation="border" role="status" />;
        break;
    }

    return <SingleCardPage title="Device Lists">{innerHTML}</SingleCardPage>;
  }
}

function TablePagination(props) {
  const { active, max } = props;

  if (max < 2) {
    return null;
  }

  let startingPage = active - Math.floor((MAX_SHOWN_PAGES - 1) / 2);
  if (startingPage < 0) {
    startingPage = 0;
  }

  let endPage = startingPage + MAX_SHOWN_PAGES;
  if (endPage > max) {
    endPage = max;
  }

  let items = [];
  for (let number = startingPage; number < endPage; number++) {
    items.push(
      <Pagination.Item
        key={number}
        active={number == active}
        onClick={() => {
          props.onPageChange(number);
        }}
      >
        {number + 1}
      </Pagination.Item>
    );
  }

  return (
    <Pagination>
      {startingPage > 0 && (
        <Pagination.Prev
          onClick={() => {
            props.onPageChange(active - 1);
          }}
        />
      )}
      {items}
      {endPage < max && (
        <Pagination.Next
          onClick={() => {
            props.onPageChange(active + 1);
          }}
        />
      )}
    </Pagination>
  );
}

function DeviceTable(props) {
  return (
    <Table responsive>
      <thead>
        <tr>
          <th>Status</th>
          <th>Device ID</th>
          <th>Last connection event</th>
        </tr>
      </thead>
      <tbody>
        {props.deviceList.map(device => (
          <DeviceRow key={device.id} device={device} />
        ))}
      </tbody>
    </Table>
  );
}

function DeviceRow(props) {
  const { device } = props;
  let colorClass;
  let lastEvent;
  let tooltipText;

  if (device.connected) {
    tooltipText = "Connected";
    colorClass = "icon-connected";
    lastEvent = `Connected at ${device.lastConnection.toLocaleString()}`;
  } else if (device.lastConnection) {
    tooltipText = "Disconnected";
    colorClass = "icon-disconnected";
    lastEvent = `Disconnected at ${device.lastDisconnection.toLocaleString()}`;
  } else {
    tooltipText = "Never connected";
    colorClass = "icon-never-connected";
    lastEvent = `Never connected`;
  }

  return (
    <tr>
      <td>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 400 }}
          style={{
            backgroundColor: "rgba(255, 100, 100, 0.85)",
            padding: "2px 10px",
            color: "white",
            borderRadius: 3
          }}
          overlay={<Tooltip>{tooltipText}</Tooltip>}
        >
          <CircleIcon className={colorClass} />
        </OverlayTrigger>
      </td>
      <td>
        <Link to={`/devices/${device.id}`}>{device.name}</Link>
      </td>
      <td>{lastEvent}</td>
    </tr>
  );
}

const CircleIcon = React.forwardRef((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));
