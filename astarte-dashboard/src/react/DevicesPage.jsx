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

import React, { useEffect, useMemo, useState } from 'react';
import {
  Button,
  Col,
  Container,
  Form,
  OverlayTrigger,
  Pagination,
  Row,
  Spinner,
  Table,
  Tooltip,
} from 'react-bootstrap';
import _ from 'lodash';

import { Link } from 'react-router-dom';
import Device from './astarte/Device';
import SingleCardPage from './ui/SingleCardPage';
import { useAlerts } from './AlertManager';
import Highlight from './components/Highlight';

const DEVICES_PER_PAGE = 20;
const DEVICES_PER_REQUEST = 100;
const MAX_SHOWN_PAGES = 10;

const hasMetadata = (metadata, filter) => {
  let found = false;
  metadata.forEach((value, key) => {
    if (key.includes(filter) || value.includes(filter)) {
      found = true;
    }
  });
  return found;
};

const matchFilters = (device, filters) => {
  const {
    deviceId = '',
    metadata = '',
    showConnected = true,
    showDisconnected = true,
    showNeverConnected = true,
  } = filters;

  if (!showConnected && device.connected) {
    return false;
  }
  if (!showDisconnected && !device.connected && device.lastConnection) {
    return false;
  }
  if (!showNeverConnected && !device.connected && !device.lastConnection) {
    return false;
  }
  if (metadata !== '' && !hasMetadata(device.metadata, metadata)) {
    return false;
  }
  if (deviceId === '') {
    return true;
  }

  const aliases = Array.from(device.aliases.values());
  return device.id.includes(deviceId) || aliases.some((alias) => alias.includes(deviceId));
};

export default ({ astarte, history }) => {
  const [phase, setPhase] = useState('loading');
  const [activePage, setActivePage] = useState(0);
  const [deviceList, setDeviceList] = useState([]);
  const [requestToken, setRequestToken] = useState(false);
  const [showSidebar, setShowSidebar] = useState(true);
  const [filters, setFilters] = useState({});

  const pageAlerts = useAlerts();
  const pagedDevices = useMemo(() => {
    const devices = deviceList.filter((device) => matchFilters(device, filters));
    return _.chunk(devices, DEVICES_PER_PAGE);
  }, [deviceList, filters]);

  const loadMoreDevices = async (fromToken, loadAllDevices = false) =>
    astarte
      .getDevices({
        details: true,
        from: fromToken,
        limit: DEVICES_PER_REQUEST,
      })
      .then((resp) => {
        const nextToken = new URLSearchParams(resp.links.next).get('from_token');
        const devices = resp.data.map((value) => Device.fromObject(value));
        setRequestToken(nextToken);

        setDeviceList((previousList) => {
          const updatedDeviceList = previousList.concat(devices);

          const pageCount = Math.ceil(updatedDeviceList.length / DEVICES_PER_PAGE);
          const shouldLoadMore = pageCount < activePage + MAX_SHOWN_PAGES || loadAllDevices;
          if (shouldLoadMore && nextToken) {
            loadMoreDevices(nextToken, loadAllDevices);
          } else {
            setPhase('ok');
          }

          return updatedDeviceList;
        });
      })
      .catch((err) => {
        pageAlerts.showError(`Couldn't retrieve the device list from Astarte: ${err.message}`);
      });

  const handlePageChange = (pageIndex) => {
    if (pageIndex > pagedDevices.length - MAX_SHOWN_PAGES && requestToken) {
      loadMoreDevices(requestToken);
    }
    setActivePage(pageIndex);
  };

  const handleFilterUpdate = (newFilters) => {
    if (activePage !== 0) {
      setActivePage(0);
    }
    if (requestToken) {
      loadMoreDevices(requestToken, true);
    }
    setFilters(newFilters);
  };

  useEffect(() => {
    loadMoreDevices();
  }, []);

  let innerHTML;

  switch (phase) {
    case 'ok':
      if (deviceList.length === 0) {
        innerHTML = <p>No registered devices</p>;
      } else {
        const devices = pagedDevices[activePage] || [];

        innerHTML = (
          <>
            <Container fluid>
              <Row>
                <Col>
                  {devices.length === 0 ? (
                    <p>No device matches current filters</p>
                  ) : (
                    <DeviceTable deviceList={devices} filters={filters} />
                  )}
                </Col>
                <Col xs="auto" className="p-1">
                  <div className="p-2 mb-2" onClick={() => setShowSidebar(!showSidebar)}>
                    <i className="fas fa-filter mr-1" />
                    {showSidebar && <b>Filters</b>}
                  </div>
                  {showSidebar && (
                    <FilterForm filters={filters} onUpdateFilters={handleFilterUpdate} />
                  )}
                </Col>
              </Row>
              <Row>
                <Col />
                <Col>
                  <TablePagination
                    activePage={activePage}
                    canLoadMorePages={!!requestToken}
                    lastPage={pagedDevices.length}
                    onPageChange={handlePageChange}
                  />
                </Col>
                <Col />
              </Row>
            </Container>
          </>
        );
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
      <pageAlerts.Alerts />
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

const TablePagination = ({ activePage, canLoadMorePages, lastPage, onPageChange }) => {
  if (lastPage < 2) {
    return null;
  }

  let endPage = activePage + Math.floor((MAX_SHOWN_PAGES + 1) / 2);
  if (endPage < MAX_SHOWN_PAGES) {
    endPage = MAX_SHOWN_PAGES;
  }
  if (endPage > lastPage) {
    endPage = lastPage;
  }

  let startingPage = endPage - MAX_SHOWN_PAGES;
  if (startingPage < 0) {
    startingPage = 0;
  }

  const items = [];
  for (let number = startingPage; number < endPage; number += 1) {
    items.push(
      <Pagination.Item
        key={number}
        active={number === activePage}
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
            onPageChange(activePage - 1);
          }}
        />
      )}
      {items}
      {(endPage < lastPage || canLoadMorePages) && (
        <Pagination.Next
          onClick={() => {
            onPageChange(activePage + 1);
          }}
        />
      )}
    </Pagination>
  );
};

const DeviceTable = ({ deviceList, filters }) => (
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
        <DeviceRow key={device.id} device={device} filters={filters} />
      ))}
    </tbody>
  </Table>
);

const DeviceRow = ({ device, filters }) => {
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
        {filters.metadata !== '' &&
          Array.from(device.metadata)
            .filter(
              ([key, value]) => key.includes(filters.metadata) || value.includes(filters.metadata),
            )
            .map(([key, value]) => (
              <HightlightMetadata
                key={key}
                field={key}
                value={value}
                highlight={filters.metadata}
              />
            ))}
      </td>
      <td>{lastEvent}</td>
    </tr>
  );
};

const HightlightMetadata = ({ field, value, highlight }) => {
  return (
    <div className="" style={{ wordWrap: 'anywhere' }}>
      <Highlight text={field} word={highlight} />
      {': '}
      <Highlight text={value} word={highlight} />
    </div>
  );
};

const CircleIcon = React.forwardRef(({ children, className, ...props }, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${className}`}>
    {children}
  </i>
));

const FilterForm = ({ filters, onUpdateFilters }) => {
  const {
    deviceId = '',
    showConnected = true,
    showDisconnected = true,
    showNeverConnected = true,
    metadata = '',
  } = filters;

  return (
    <Form className="p-2">
      <Form.Group controlId="filterId" className="mb-3">
        <Form.Label>
          <b>Device ID/name</b>
        </Form.Label>
        <Form.Control
          type="text"
          value={deviceId}
          onChange={(e) => onUpdateFilters({ ...filters, deviceId: e.target.value })}
        />
      </Form.Group>
      <Form.Group controlId="filterStatus" className="mb-3">
        <Form.Label>
          <b>Device status</b>
        </Form.Label>
        <Form.Check
          type="checkbox"
          id="checkbox-connected"
          label="Connected"
          checked={showConnected}
          onChange={(e) => onUpdateFilters({ ...filters, showConnected: e.target.checked })}
        />
        <Form.Check
          type="checkbox"
          id="checkbox-disconnected"
          label="Disconnected"
          checked={showDisconnected}
          onChange={(e) => onUpdateFilters({ ...filters, showDisconnected: e.target.checked })}
        />
        <Form.Check
          type="checkbox"
          id="checkbox-never-connected"
          label="Never connected"
          checked={showNeverConnected}
          onChange={(e) => onUpdateFilters({ ...filters, showNeverConnected: e.target.checked })}
        />
      </Form.Group>
      <Form.Group controlId="filterMetadata" className="mb-3">
        <Form.Label>
          <b>Metadata</b>
        </Form.Label>
        <Form.Control
          type="text"
          value={metadata}
          onChange={(e) => onUpdateFilters({ ...filters, metadata: e.target.value })}
        />
      </Form.Group>
    </Form>
  );
};
