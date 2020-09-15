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

import React, { useEffect, useState } from 'react';
import {
  Container,
  Row,
  Col,
  Button,
  OverlayTrigger,
  Pagination,
  Spinner,
  Table,
  Tooltip,
} from 'react-bootstrap';

import { Link } from 'react-router-dom';
import Device from './astarte/Device';
import SingleCardPage from './ui/SingleCardPage';

const DEVICES_PER_PAGE = 20;
const MAX_SHOWN_PAGES = 10;

export default ({ astarte, history }) => {
  const [phase, setPhase] = useState('loading');
  const [totalDevices, setTotalDevices] = useState(null);
  const [activePage, setActivePage] = useState(0);
  const [maxPage, setMaxPage] = useState(0);
  const [cachedPages, setCachedPages] = useState([]);

  const handleDevicesRequest = (pageIndex, response) => {
    const token = new URLSearchParams(response.links.next).get('from_token');
    const deviceList = response.data.map((value) => Device.fromObject(value));
    cachedPages[pageIndex] = {
      devices: deviceList,
      token,
    };
    setCachedPages([...cachedPages]);
    if (pageIndex === activePage) {
      setPhase('ok');
    }
    const pagesToCache = activePage + MAX_SHOWN_PAGES + 1;
    if (pageIndex < pagesToCache) {
      // eslint-disable-next-line no-use-before-define
      cachePage(pageIndex + 1);
    }
    return null;
  };

  const cachePage = (pageIndex) => {
    if (pageIndex === 0) {
      astarte
        .getDevices({
          details: true,
          limit: DEVICES_PER_PAGE,
        })
        .then((response) => handleDevicesRequest(pageIndex, response))
        .catch(console.log);
    } else {
      const { token } = cachedPages[pageIndex - 1];
      if (token) {
        astarte
          .getDevices({
            details: true,
            from: token,
            limit: DEVICES_PER_PAGE,
          })
          .then((response) => handleDevicesRequest(pageIndex, response))
          .catch(console.log);
      }
    }
    return null;
  };

  const loadPage = (pageIndex) => {
    if (!cachedPages[pageIndex]) {
      console.log('Loading a page not ready to be shown');
      return;
    }
    setActivePage(pageIndex);
    setPhase('ok');
    const lastCachedPage = cachedPages.length - 1;
    const pagesToCache = pageIndex + MAX_SHOWN_PAGES + 1;
    if (lastCachedPage < pagesToCache) {
      cachePage(lastCachedPage + 1);
    }
  };

  useEffect(() => {
    const handleStatsRequest = (response) => {
      const newTotalDevices = response.data.total_devices;
      if (newTotalDevices > 0) {
        setTotalDevices(newTotalDevices);
        setActivePage(0);
        setMaxPage(Math.ceil(newTotalDevices / DEVICES_PER_PAGE));
        setCachedPages([]);
        cachePage(0);
      } else {
        setTotalDevices(0);
        setPhase('ok');
      }
      return null;
    };
    const handleError = () => {
      setPhase('err');
    };
    astarte
      .getDevicesStats()
      .then(handleStatsRequest)
      .catch(handleError);
  }, [astarte]);

  let innerHTML;

  switch (phase) {
    case 'ok':
      if (totalDevices) {
        const viewAblePages = Math.min(cachedPages.length, maxPage);
        const devices = cachedPages[activePage].devices || [];

        innerHTML = (
          <>
            <DeviceTable deviceList={devices} />
            <Container fluid>
              <Row>
                <Col />
                <Col>
                  <TablePagination
                    active={activePage}
                    max={viewAblePages}
                    onPageChange={loadPage}
                  />
                </Col>
                <Col />
              </Row>
            </Container>
          </>
        );
      } else {
        innerHTML = <p>No registered devices</p>;
      }
      break;

    case 'err':
      innerHTML = <p>Couldn&apos;t load the device list</p>;
      break;

    default:
      innerHTML = (
        <div>
          <Spinner animation="border" role="status" />
        </div>
      );
      break;
  }

  return (
    <SingleCardPage title="Devices">
      {innerHTML}
      <Button
        variant="primary"
        onClick={() => {
          history.push('/devices/register');
        }}
      >
        Register a new device
      </Button>
    </SingleCardPage>
  );
};

const TablePagination = ({ active, max, onPageChange }) => {
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

  const items = [];
  for (let number = startingPage; number < endPage; number += 1) {
    items.push(
      <Pagination.Item
        key={number}
        active={number === active}
        onClick={() => {
          onPageChange(number);
        }}
      >
        {number + 1}
      </Pagination.Item>,
    );
  }

  return (
    <Pagination>
      {startingPage > 0 && (
        <Pagination.Prev
          onClick={() => {
            onPageChange(active - 1);
          }}
        />
      )}
      {items}
      {endPage < max && (
        <Pagination.Next
          onClick={() => {
            onPageChange(active + 1);
          }}
        />
      )}
    </Pagination>
  );
};

const DeviceTable = ({ deviceList }) => (
  <Table responsive>
    <thead>
      <tr>
        <th>Status</th>
        <th>Device handle</th>
        <th>Last connection event</th>
      </tr>
    </thead>
    <tbody>
      {deviceList.map((device) => (
        <DeviceRow key={device.id} device={device} />
      ))}
    </tbody>
  </Table>
);

const DeviceRow = ({ device }) => {
  let colorClass;
  let lastEvent;
  let tooltipText;

  if (device.connected) {
    tooltipText = 'Connected';
    colorClass = 'icon-connected';
    lastEvent = `Connected on ${device.lastConnection.toLocaleString()}`;
  } else if (device.lastConnection) {
    tooltipText = 'Disconnected';
    colorClass = 'icon-disconnected';
    lastEvent = `Disconnected on ${device.lastDisconnection.toLocaleString()}`;
  } else {
    tooltipText = 'Never connected';
    colorClass = 'icon-never-connected';
    lastEvent = 'Never connected';
  }

  return (
    <tr>
      <td>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 400 }}
          style={{
            backgroundColor: 'rgba(255, 100, 100, 0.85)',
            padding: '2px 10px',
            color: 'white',
            borderRadius: 3,
          }}
          overlay={<Tooltip>{tooltipText}</Tooltip>}
        >
          <CircleIcon className={colorClass} />
        </OverlayTrigger>
      </td>
      <td className={device.hasNameAlias ? '' : 'text-monospace'}>
        <Link to={`/devices/${device.id}`}>{device.name}</Link>
      </td>
      <td>{lastEvent}</td>
    </tr>
  );
};

const CircleIcon = React.forwardRef(
  ({ children, className, ...props }, ref) => (
    <i ref={ref} {...props} className={`fas fa-circle ${className}`}>
      {children}
    </i>
  ),
);
