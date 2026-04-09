/*
   This file is part of Astarte.

   Copyright 2026 SECO Mind Srl

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

import React, { useState } from 'react';
import { Badge, Button, Col, Container, Form, Modal, Row, Spinner, Table } from 'react-bootstrap';
import { useNavigate } from 'react-router-dom';

import { useAstarte } from './AstarteManager';
import useFetch from './hooks/useFetch';
import useInterval from './hooks/useInterval';
import Empty from './components/Empty';
import Icon from './components/Icon';
import WaitForData from './components/WaitForData';

type VoucherStatus = 'created' | 'claimed';

type FdoVoucher = {
  guid: string;
  status: VoucherStatus | null;
  input_voucher: string | null;
  output_voucher: string | null;
  output_guid: string | null;
};

const STATUSES: VoucherStatus[] = ['created', 'claimed'];

const formatStatus = (status: VoucherStatus | null): string =>
  status ? status.charAt(0).toUpperCase() + status.slice(1) : 'Unknown';

const statusVariant = (status: VoucherStatus | null) =>
  status === 'claimed' ? 'success' : 'secondary';

// ── Status Filter ────────────────────────────────────────────────────────────

interface StatusFilterProps {
  allVouchers: FdoVoucher[];
  activeFilter: VoucherStatus | null;
  onSelect: (s: VoucherStatus | null) => void;
}

const StatusFilter = ({
  allVouchers,
  activeFilter,
  onSelect,
}: StatusFilterProps): React.ReactElement => {
  const countByStatus = (s: VoucherStatus) => allVouchers.filter((v) => v.status === s).length;

  return (
    <div className="d-flex align-items-center gap-2 flex-wrap mb-3">
      <span className="text-muted small fw-semibold me-1">Filter by status:</span>
      <Button
        size="sm"
        variant={activeFilter === null ? 'secondary' : 'outline-secondary'}
        onClick={() => onSelect(null)}
      >
        All
      </Button>
      {STATUSES.map((s) => {
        const count = countByStatus(s);
        const active = activeFilter === s;
        return (
          <Button
            key={s}
            size="sm"
            variant={active ? statusVariant(s) : `outline-${statusVariant(s)}`}
            onClick={() => onSelect(activeFilter === s ? null : s)}
          >
            {formatStatus(s)}
            <span
              className={`ms-2 badge rounded-pill ${
                active ? 'bg-white text-dark' : `bg-${statusVariant(s)} text-white`
              }`}
            >
              {count}
            </span>
          </Button>
        );
      })}
    </div>
  );
};

// ── Table skeleton rows ──────────────────────────────────────────────────────

const LoadingRow = (): React.ReactElement => (
  <tr>
    <td colSpan={3} className="text-center py-4">
      <Spinner animation="border" role="status" />
    </td>
  </tr>
);

interface ErrorRowProps {
  onRetry: () => void;
  errorMessage?: string;
}

const ErrorRow = ({ onRetry, errorMessage }: ErrorRowProps): React.ReactElement => (
  <tr>
    <td colSpan={3}>
      <Empty
        title={
          errorMessage?.includes('401') || errorMessage?.includes('403')
            ? "The JWT token is invalid or does not match the realm's public key."
            : "Couldn't load ownership vouchers"
        }
        onRetry={onRetry}
      />
    </td>
  </tr>
);

// ── Single table row ─────────────────────────────────────────────────────────

interface VoucherRowProps {
  voucher: FdoVoucher;
  onView: () => void;
}

const VoucherRow = ({ voucher, onView }: VoucherRowProps): React.ReactElement => (
  <tr>
    <td>
      <Icon icon="devices" className="me-2" />
      <code title={voucher.guid}>{voucher.guid}</code>
    </td>
    <td>
      <Badge bg={statusVariant(voucher.status)}>{formatStatus(voucher.status)}</Badge>
    </td>
    <td className="text-end">
      <Button variant="outline-secondary" size="sm" onClick={onView}>
        <Icon icon="documentation" className="me-1" />
        View details
      </Button>
    </td>
  </tr>
);

// ── Detail modal ─────────────────────────────────────────────────────────────

interface CopyButtonProps {
  text: string;
  label?: string;
}

const CopyButton = ({ text, label = 'Copy' }: CopyButtonProps): React.ReactElement => {
  const [copied, setCopied] = useState(false);
  const handleCopy = () => {
    navigator.clipboard.writeText(text).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };
  return (
    <Button variant={copied ? 'success' : 'outline-secondary'} size="sm" onClick={handleCopy}>
      <Icon icon="copyPaste" className="me-1" />
      {copied ? 'Copied!' : label}
    </Button>
  );
};

interface VoucherDetailModalProps {
  voucher: FdoVoucher;
  onClose: () => void;
}

const VoucherDetailModal = ({ voucher, onClose }: VoucherDetailModalProps): React.ReactElement => (
  <Modal show onHide={onClose} size="lg" centered>
    <Modal.Header closeButton>
      <Modal.Title>
        <Icon icon="devices" className="me-2" />
        Voucher Details
      </Modal.Title>
    </Modal.Header>
    <Modal.Body>
      {/* GUID */}
      <div className="mb-3">
        <div className="d-flex justify-content-between align-items-center mb-1">
          <strong>GUID</strong>
          <CopyButton text={voucher.guid} />
        </div>
        <Form.Control
          readOnly
          value={voucher.guid}
          className="font-monospace"
          style={{ fontSize: '0.85rem' }}
        />
      </div>

      {/* Status */}
      <div className="mb-4">
        <strong>Status</strong>
        <div className="mt-1">
          <Badge bg={statusVariant(voucher.status)} className="fs-6 px-3 py-2">
            {formatStatus(voucher.status)}
          </Badge>
        </div>
      </div>

      {/* Input Voucher */}
      {voucher.input_voucher && (
        <div className="mb-4">
          <div className="d-flex justify-content-between align-items-center mb-1">
            <strong>Input Voucher (PEM)</strong>
            <CopyButton text={voucher.input_voucher} />
          </div>
          <Form.Control
            as="textarea"
            readOnly
            value={voucher.input_voucher}
            rows={6}
            className="font-monospace"
            style={{ fontSize: '0.8rem' }}
          />
        </div>
      )}

      {/* Replacement / Output section */}
      {voucher.output_guid || voucher.output_voucher ? (
        <>
          <hr />
          <p className="text-muted small fw-semibold mb-3">Replacement (TO2 output)</p>

          {voucher.output_guid && (
            <div className="mb-3">
              <div className="d-flex justify-content-between align-items-center mb-1">
                <strong>Output GUID</strong>
                <CopyButton text={voucher.output_guid} />
              </div>
              <Form.Control
                readOnly
                value={voucher.output_guid}
                className="font-monospace"
                style={{ fontSize: '0.85rem' }}
              />
            </div>
          )}

          {voucher.output_voucher && (
            <div className="mb-3">
              <div className="d-flex justify-content-between align-items-center mb-1">
                <strong>Output Voucher (PEM)</strong>
                <CopyButton text={voucher.output_voucher} />
              </div>
              <Form.Control
                as="textarea"
                readOnly
                value={voucher.output_voucher}
                rows={6}
                className="font-monospace"
                style={{ fontSize: '0.8rem' }}
              />
            </div>
          )}
        </>
      ) : (
        <p className="text-muted small fst-italic">No replacement voucher has been set yet.</p>
      )}
    </Modal.Body>
    <Modal.Footer>
      <Button variant="secondary" onClick={onClose}>
        Close
      </Button>
    </Modal.Footer>
  </Modal>
);

// ── Page ─────────────────────────────────────────────────────────────────────

export default (): React.ReactElement => {
  const navigate = useNavigate();
  const [selectedVoucher, setSelectedVoucher] = useState<FdoVoucher | null>(null);
  const [activeFilter, setActiveFilter] = useState<VoucherStatus | null>(null);
  const astarte = useAstarte();
  const vouchersFetcher = useFetch(astarte.client.listFdoVouchers);
  useInterval(vouchersFetcher.refresh, 30000);

  const applyFilters = (vouchers: FdoVoucher[]) =>
    activeFilter === null ? vouchers : vouchers.filter((v) => v.status === activeFilter);

  return (
    <Container fluid className="p-3" data-testid="fdo-vouchers-page">
      <Row>
        <Col>
          <h2>FDO Ownership Vouchers</h2>
        </Col>
        <Col xs="auto">
          <Button variant="primary" onClick={() => navigate('/fdo-vouchers/new')}>
            <Icon icon="add" className="me-2" />
            Upload new voucher
          </Button>
        </Col>
      </Row>
      <Row className="mt-3">
        <Col>
          <Table responsive hover>
            <thead>
              <tr>
                <th>GUID</th>
                <th>Status</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <WaitForData
                data={vouchersFetcher.value}
                status={vouchersFetcher.status}
                fallback={<LoadingRow />}
                errorFallback={
                  <ErrorRow
                    onRetry={vouchersFetcher.refresh}
                    errorMessage={vouchersFetcher.error?.message}
                  />
                }
              >
                {(vouchers) => {
                  const filtered = applyFilters(vouchers);
                  return (
                    <>
                      <tr>
                        <td colSpan={3} className="border-0 pb-0">
                          <StatusFilter
                            allVouchers={vouchers}
                            activeFilter={activeFilter}
                            onSelect={setActiveFilter}
                          />
                        </td>
                      </tr>
                      {filtered.length === 0 ? (
                        <tr>
                          <td colSpan={3} className="text-center py-4">
                            {vouchers.length === 0 ? (
                              <Empty title="No ownership vouchers yet" />
                            ) : (
                              <div className="text-muted">
                                <p className="mb-1">No vouchers match the selected filter.</p>
                                <Button
                                  variant="link"
                                  className="p-0"
                                  onClick={() => setActiveFilter(null)}
                                >
                                  Clear filter
                                </Button>
                              </div>
                            )}
                          </td>
                        </tr>
                      ) : (
                        filtered.map((v) => (
                          <VoucherRow
                            key={v.guid}
                            voucher={v}
                            onView={() => setSelectedVoucher(v)}
                          />
                        ))
                      )}
                    </>
                  );
                }}
              </WaitForData>
            </tbody>
          </Table>
        </Col>
      </Row>
      {selectedVoucher && (
        <VoucherDetailModal voucher={selectedVoucher} onClose={() => setSelectedVoucher(null)} />
      )}
    </Container>
  );
};
