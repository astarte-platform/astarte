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
  attributeKey?: string;
  attributeValue?: string;
}

const DEVICES_PER_PAGE = 20;
const DEVICES_PER_REQUEST = 100;
const MAX_SHOWN_PAGES = 10;

const matchAttribute = (
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

interface MatchedAttributesProps {
  filters: DeviceFilters;
  attributes: AstarteDevice['attributes'];
}

const MatchedAttributes = ({
  filters,
  attributes,
}: MatchedAttributesProps): React.ReactElement | null => {
  const { attributeKey = '', attributeValue = '' } = filters;

  if (attributeKey === '' && attributeValue === '') {
    return null;
  }

  return (
    <>
      {Array.from(attributes)
        .filter(([key, value]) => matchAttribute(key, value, attributeKey, attributeValue))
        .map(([key, value]) => (
          <div key={key} style={{ overflowWrap: 'anywhere' }}>
            <Highlight word={attributeKey}>{key}</Highlight>
            {': '}
            <Highlight word={attributeValue}>{value}</Highlight>
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
        <MatchedAttributes filters={filters} attributes={device.attributes} />
      </td>
      <td>{lastEvent}</td>
    </tr>
  );
};

interface DeviceTableProps {
  deviceList: AstarteDevice[];
  filters: DeviceFilters;
  isLoading?: boolean;
}

const DeviceTable = ({ deviceList, filters, isLoading }: DeviceTableProps): React.ReactElement => (
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
      {!isLoading && deviceList.length === 0 && (
        <tr>
          <td colSpan={3}>
            <p>No device matches current filters</p>
          </td>
        </tr>
      )}
    </tbody>
  </Table>
);

const matchFilters = (device: AstarteDevice, filters: DeviceFilters) => {
  const {
    deviceId = '',
    attributeKey = '',
    attributeValue = '',
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
    (attributeKey !== '' || attributeValue !== '') &&
    !Array.from(device.attributes).some(([key, value]) =>
      matchAttribute(key, value, attributeKey, attributeValue),
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
  isLoadingMorePages?: boolean;
  lastPage: number;
  onPageChange: (pageIndex: number) => void;
}

const TablePagination = ({
  activePage,
  canLoadMorePages,
  isLoadingMorePages,
  lastPage,
  onPageChange,
}: TablePaginationProps): React.ReactElement | null => {
  if (lastPage < 2 && !isLoadingMorePages) {
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
          disabled={isLoadingMorePages}
          onClick={() => {
            onPageChange(activePage + 1);
          }}
        >
          {isLoadingMorePages && <Spinner animation="border" role="status" size="sm" />}
        </Pagination.Next>
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
    attributeKey = '',
    attributeValue = '',
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
        <b>Attributes</b>
      </div>
      <Form.Group controlId="filterAttributeKey" className="mb-2">
        <Form.Label>Key</Form.Label>
        <Form.Control
          type="text"
          value={attributeKey}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, attributeKey: e.target.value })
          }
        />
      </Form.Group>
      <Form.Group controlId="filterAttributeValue" className="mb-4">
        <Form.Label>Value</Form.Label>
        <Form.Control
          type="text"
          value={attributeValue}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
            onUpdateFilters({ ...filters, attributeValue: e.target.value })
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
  const [isLoadingMoreDevices, setIsLoadingMoreDevices] = useState(false);
  const navigate = useNavigate();

  const pageAlerts = useAlerts();
  const pagedDevices = useMemo(() => {
    const devices = deviceList.filter((device) => matchFilters(device, filters));
    return _.chunk(devices, DEVICES_PER_PAGE);
  }, [deviceList, filters]);

  const loadMoreDevices = async (
    currentDeviceList: AstarteDevice[],
    fromToken?: string,
    loadAllDevices = false,
  ): Promise<void> => {
    setIsLoadingMoreDevices(true);
    return astarte
      .getDevices({
        details: true,
        from: fromToken,
        limit: DEVICES_PER_REQUEST,
      })
      .then(({ devices, nextToken }) => {
        const updatedDeviceList = currentDeviceList.concat(devices);
        setRequestToken(nextToken);
        setDeviceList(updatedDeviceList);
        const pageCount = Math.ceil(updatedDeviceList.length / DEVICES_PER_PAGE);
        const shouldLoadMore = pageCount < activePage + MAX_SHOWN_PAGES || loadAllDevices;
        setPhase('ok');
        if (shouldLoadMore && nextToken) {
          return loadMoreDevices(updatedDeviceList, nextToken, loadAllDevices);
        }
        return Promise.resolve();
      })
      .catch((err) => {
        pageAlerts.showError(`Couldn't retrieve the device list from Astarte: ${err.message}`);
      })
      .finally(() => {
        setIsLoadingMoreDevices(false);
      });
  };

  const handlePageChange = (pageIndex: number) => {
    if (pageIndex > pagedDevices.length - MAX_SHOWN_PAGES && requestToken) {
      loadMoreDevices(deviceList, requestToken);
    }
    setActivePage(pageIndex);
  };

  const handleFilterUpdate = (newFilters: DeviceFilters) => {
    if (activePage !== 0) {
      setActivePage(0);
    }
    if (requestToken && !isLoadingMoreDevices) {
      loadMoreDevices(deviceList, requestToken, true);
    }
    setFilters(newFilters);
  };

  useEffect(() => {
    loadMoreDevices(deviceList);
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
                  <DeviceTable
                    deviceList={devices}
                    filters={filters}
                    isLoading={isLoadingMoreDevices}
                  />
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
                    isLoadingMorePages={isLoadingMoreDevices}
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
