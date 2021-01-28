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
import AstarteClient from 'astarte-client';
import type { AstarteDevice } from 'astarte-client';

import { Link, useNavigate } from 'react-router-dom';
import SingleCardPage from './ui/SingleCardPage';
import { useAlerts } from './AlertManager';
import Highlight from './components/Highlight';

interface DeviceFilters {
  deviceId?: AstarteDevice['id'];
  showConnected?: boolean;
  showDisconnected?: boolean;
  showNeverConnected?: boolean;
  metadataKey?: string;
  metadataValue?: string;
}

const DEVICES_PER_PAGE = 20;
const DEVICES_PER_REQUEST = 100;
const MAX_SHOWN_PAGES = 10;

const matchMetadata = (
  key: string,
  value: string,
  filterKey: string,
  filterValue: string,
): boolean => {
  if (filterKey !== '' && !key.includes(filterKey)) {
    return false;
  }
  if (filterValue !== '' && !value.includes(filterValue)) {
    return false;
  }
  return true;
};

interface MatchedMetadataProps {
  filters: DeviceFilters;
  metadata: AstarteDevice['metadata'];
}

const MatchedMetadata = ({
  filters,
  metadata,
}: MatchedMetadataProps): React.ReactElement | null => {
  const { metadataKey = '', metadataValue = '' } = filters;

  if (metadataKey === '' && metadataValue === '') {
    return null;
  }

  return (
    <>
      {Array.from(metadata)
        .filter(([key, value]) => matchMetadata(key, value, metadataKey, metadataValue))
        .map(([key, value]) => (
          <div key={key} style={{ overflowWrap: 'anywhere' }}>
            <Highlight word={metadataKey}>{key}</Highlight>
            {': '}
            <Highlight word={metadataValue}>{value}</Highlight>
          </div>
        ))}
    </>
  );
};

const CircleIcon = React.forwardRef<HTMLElement, React.HTMLProps<HTMLElement>>(
  ({ children, className, ...props }, ref) => (
    <i ref={ref} {...props} className={`fas fa-circle ${className}`}>
      {children}
    </i>
  ),
);

interface DeviceRowProps {
  device: AstarteDevice;
  filters: DeviceFilters;
}

const DeviceRow = ({ device, filters }: DeviceRowProps): React.ReactElement => {
  let colorClass;
  let lastEvent;
  let tooltipText;

  if (device.isConnected) {
    tooltipText = 'Connected';
    colorClass = 'icon-connected';
    lastEvent = `Connected on ${(device.lastConnection as Date).toLocaleString()}`;
  } else if (device.lastConnection) {
    tooltipText = 'Disconnected';
    colorClass = 'icon-disconnected';
    lastEvent = `Disconnected on ${(device.lastDisconnection as Date).toLocaleString()}`;
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
          overlay={<Tooltip id={device.id}>{tooltipText}</Tooltip>}
        >
          <CircleIcon className={colorClass} />
        </OverlayTrigger>
      </td>
      <td className={device.hasNameAlias ? '' : 'text-monospace'}>
        <Link to={`/devices/${device.id}/edit`}>{device.name}</Link>
        <MatchedMetadata filters={filters} metadata={device.metadata} />
      </td>
      <td>{lastEvent}</td>
    </tr>
  );
};

interface DeviceTableProps {
  deviceList: AstarteDevice[];
  filters: DeviceFilters;
}

const DeviceTable = ({ deviceList, filters }: DeviceTableProps): React.ReactElement => (
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

const matchFilters = (device: AstarteDevice, filters: DeviceFilters) => {
  const {
    deviceId = '',
    metadataKey = '',
    metadataValue = '',
    showConnected = true,
    showDisconnected = true,
    showNeverConnected = true,
  } = filters;

  if (!showConnected && device.isConnected) {
    return false;
  }
  if (!showDisconnected && !device.isConnected && device.lastConnection) {
    return false;
  }
  if (!showNeverConnected && !device.isConnected && !device.lastConnection) {
    return false;
  }

  if (
    (metadataKey !== '' || metadataValue !== '') &&
    !Array.from(device.metadata).some(([key, value]) =>
      matchMetadata(key, value, metadataKey, metadataValue),
    )
  ) {
    return false;
  }

  if (deviceId === '') {
    return true;
  }

  const aliases = Array.from(device.aliases.values());
  return device.id.includes(deviceId) || aliases.some((alias) => alias.includes(deviceId));
};

interface TablePaginationProps {
  activePage: number;
  canLoadMorePages: boolean;
  lastPage: number;
  onPageChange: (pageIndex: number) => void;
}

const TablePagination = ({
  activePage,
  canLoadMorePages,
  lastPage,
  onPageChange,
}: TablePaginationProps): React.ReactElement | null => {
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

interface FilterFormProps {
  filters: DeviceFilters;
  onUpdateFilters: (filters: DeviceFilters) => void;
}

const FilterForm = ({ filters, onUpdateFilters }: FilterFormProps): React.ReactElement => {
  const {
    deviceId = '',
    showConnected = true,
    showDisconnected = true,
    showNeverConnected = true,
    metadataKey = '',
    metadataValue = '',
  } = filters;

  return (
    <Form className="p-2">
      <Form.Group controlId="filterId" className="mb-4">
        <Form.Label>
          <b>Device ID/name</b>
        </Form.Label>
        <Form.Control
          type="text"
          value={deviceId}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, deviceId: e.target.value })
          }
        />
      </Form.Group>
      <Form.Group controlId="filterStatus" className="mb-4">
        <Form.Label>
          <b>Device status</b>
        </Form.Label>
        <Form.Check
          type="checkbox"
          id="checkbox-connected"
          label="Connected"
          checked={showConnected}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, showConnected: e.target.checked })
          }
        />
        <Form.Check
          type="checkbox"
          id="checkbox-disconnected"
          label="Disconnected"
          checked={showDisconnected}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, showDisconnected: e.target.checked })
          }
        />
        <Form.Check
          type="checkbox"
          id="checkbox-never-connected"
          label="Never connected"
          checked={showNeverConnected}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, showNeverConnected: e.target.checked })
          }
        />
      </Form.Group>
      <div className="mb-2">
        <b>Metadata</b>
      </div>
      <Form.Group controlId="filterMetadataKey" className="mb-2">
        <Form.Label>Key</Form.Label>
        <Form.Control
          type="text"
          value={metadataKey}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, metadataKey: e.target.value })
          }
        />
      </Form.Group>
      <Form.Group controlId="filterMetadataValue" className="mb-4">
        <Form.Label>Value</Form.Label>
        <Form.Control
          type="text"
          value={metadataValue}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, metadataValue: e.target.value })
          }
        />
      </Form.Group>
    </Form>
  );
};

interface Props {
  astarte: AstarteClient;
}

export default ({ astarte }: Props): React.ReactElement => {
  const [phase, setPhase] = useState<'loading' | 'ok' | 'err'>('loading');
  const [activePage, setActivePage] = useState(0);
  const [deviceList, setDeviceList] = useState<AstarteDevice[]>([]);
  const [requestToken, setRequestToken] = useState<string | null>(null);
  const [showSidebar, setShowSidebar] = useState(true);
  const [filters, setFilters] = useState({});
  const navigate = useNavigate();

  const pageAlerts = useAlerts();
  const pagedDevices = useMemo(() => {
    const devices = deviceList.filter((device) => matchFilters(device, filters));
    return _.chunk(devices, DEVICES_PER_PAGE);
  }, [deviceList, filters]);

  const loadMoreDevices = async (fromToken?: string, loadAllDevices = false) =>
    astarte
      .getDevices({
        details: true,
        from: fromToken,
        limit: DEVICES_PER_REQUEST,
      })
      .then(({ devices, nextToken }) => {
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

  const handlePageChange = (pageIndex: number) => {
    if (pageIndex > pagedDevices.length - MAX_SHOWN_PAGES && requestToken) {
      loadMoreDevices(requestToken);
    }
    setActivePage(pageIndex);
  };

  const handleFilterUpdate = (newFilters: DeviceFilters) => {
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
          navigate('/devices/register');
        }}
      >
        Register a new device
      </Button>
    </SingleCardPage>
  );
};
