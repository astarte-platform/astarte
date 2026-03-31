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
import { Button, Col, Container, Form, Modal, Row, Spinner, Table } from 'react-bootstrap';
import { useNavigate } from 'react-router-dom';

import { useAstarte } from './AstarteManager';
import useFetch from './hooks/useFetch';
import useInterval from './hooks/useInterval';
import Empty from './components/Empty';
import Icon from './components/Icon';
import WaitForData from './components/WaitForData';

type FdoOwnerKey = { key_name: string; key_algorithm: string };

const ALGORITHMS = ['es256', 'es384', 'rs256', 'rs384'] as const;
type Algorithm = (typeof ALGORITHMS)[number];

interface AlgorithmFilterProps {
  allKeys: FdoOwnerKey[];
  activeFilter: Algorithm | null;
  onSelect: (algo: Algorithm | null) => void;
}

const AlgorithmFilter = ({
  allKeys,
  activeFilter,
  onSelect,
}: AlgorithmFilterProps): React.ReactElement => {
  const countByAlgo = (algo: Algorithm) =>
    allKeys.filter((k) => k.key_algorithm === algo).length;

  return (
    <div className="d-flex align-items-center gap-2 flex-wrap mb-3">
      <span className="text-muted small fw-semibold me-1">Filter by algorithm:</span>
      <Button
        size="sm"
        variant={activeFilter === null ? 'secondary' : 'outline-secondary'}
        onClick={() => onSelect(null)}
      >
        All
      </Button>
      {ALGORITHMS.map((algo) => {
        const count = countByAlgo(algo);
        const active = activeFilter === algo;
        return (
          <Button
            key={algo}
            size="sm"
            variant={active ? 'primary' : 'outline-primary'}
            onClick={() => onSelect(activeFilter === algo ? null : algo)}
          >
            {algo.toUpperCase()}
            <span
              className={`ms-2 badge rounded-pill ${active ? 'bg-white text-primary' : 'bg-primary text-white'}`}
            >
              {count}
            </span>
          </Button>
        );
      })}
    </div>
  );
};

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
            : "Couldn't load owner keys"
        }
        onRetry={onRetry}
      />
    </td>
  </tr>
);

interface KeyRowProps {
  keyName: string;
  keyAlgorithm: string;
  onViewPublicKey: () => void;
}

const KeyRow = ({ keyName, keyAlgorithm, onViewPublicKey }: KeyRowProps): React.ReactElement => (
  <tr>
    <td>
      <Icon icon="key" className="me-2" />
      {keyName}
    </td>
    <td>
      <code>{keyAlgorithm}</code>
    </td>
    <td className="text-end">
      <Button variant="outline-secondary" size="sm" onClick={onViewPublicKey}>
        <Icon icon="documentation" className="me-1" />
        View public key
      </Button>
    </td>
  </tr>
);

interface PublicKeyModalProps {
  keyName: string;
  keyAlgorithm: string;
  onClose: () => void;
}

const PublicKeyModal = ({ keyName, keyAlgorithm, onClose }: PublicKeyModalProps): React.ReactElement => {
  const astarte = useAstarte();
  const keyFetcher = useFetch(astarte.client.getFdoOwnerKey, keyAlgorithm, keyName);
  const [copied, setCopied] = useState(false);

  const handleCopy = (publicKey: string) => {
    navigator.clipboard.writeText(publicKey).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  return (
    <Modal show onHide={onClose} size="lg" centered>
      <Modal.Header closeButton>
        <Modal.Title>
          <Icon icon="key" className="me-2" />
          Public Key — {keyName}
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        {keyFetcher.status === 'loading' && (
          <div className="text-center py-4">
            <Spinner animation="border" role="status" />
          </div>
        )}
        {keyFetcher.status === 'err' && (
          <Empty title="Couldn't load public key" onRetry={() => keyFetcher.refresh(keyAlgorithm, keyName)} />
        )}
        {keyFetcher.status === 'ok' && keyFetcher.value && (
          <>
            <div className="d-flex justify-content-end mb-2">
              <Button
                variant={copied ? 'success' : 'outline-secondary'}
                size="sm"
                onClick={() => handleCopy(keyFetcher.value.public_key)}
              >
                <Icon icon="copyPaste" className="me-1" />
                {copied ? 'Copied!' : 'Copy'}
              </Button>
            </div>
            <Form.Control
              as="textarea"
              readOnly
              value={keyFetcher.value.public_key}
              rows={8}
              className="font-monospace"
              style={{ fontSize: '0.8rem' }}
            />
          </>
        )}
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onClose}>
          Close
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default (): React.ReactElement => {
  const navigate = useNavigate();
  const [selectedKey, setSelectedKey] = useState<FdoOwnerKey | null>(null);
  const [activeFilter, setActiveFilter] = useState<Algorithm | null>(null);
  const astarte = useAstarte();
  const keysFetcher = useFetch(astarte.client.listFdoOwnerKeys);
  useInterval(keysFetcher.refresh, 30000);

  const applyFilters = (keys: FdoOwnerKey[]) =>
    activeFilter === null ? keys : keys.filter((k) => k.key_algorithm === activeFilter);

  return (
    <Container fluid className="p-3" data-testid="fdo-owner-keys-page">
      <Row>
        <Col>
          <h2>FDO Owner Keys</h2>
        </Col>
        <Col xs="auto">
          <Button variant="primary" onClick={() => navigate('/fdo-owner-keys/new')}>
            <Icon icon="add" className="me-2" />
            Create new key
          </Button>
        </Col>
      </Row>
      <Row className="mt-3">
        <Col>
          <Table responsive hover>
            <thead>
              <tr>
                <th>Key Name</th>
                <th>Algorithm</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <WaitForData
                data={keysFetcher.value}
                status={keysFetcher.status}
                fallback={<LoadingRow />}
                errorFallback={
                  <ErrorRow
                    onRetry={keysFetcher.refresh}
                    errorMessage={keysFetcher.error?.message}
                  />
                }
              >
                {(keys) => {
                  const filtered = applyFilters(keys);
                  return (
                    <>
                      <tr>
                        <td colSpan={3} className="border-0 pb-0">
                          <AlgorithmFilter
                            allKeys={keys}
                            activeFilter={activeFilter}
                            onSelect={setActiveFilter}
                          />
                        </td>
                      </tr>
                      {filtered.length === 0 ? (
                        <tr>
                          <td colSpan={3} className="text-center py-4">
                            {keys.length === 0 ? (
                              <Empty title="No owner keys yet" />
                            ) : (
                              <div className="text-muted">
                                <p className="mb-1">No keys match the selected filters.</p>
                                <Button variant="link" className="p-0" onClick={() => setActiveFilter(null)}>
                                  Clear filters
                                </Button>
                              </div>
                            )}
                          </td>
                        </tr>
                      ) : (
                        filtered.map((key) => (
                          <KeyRow
                            key={key.key_name}
                            keyName={key.key_name}
                            keyAlgorithm={key.key_algorithm}
                            onViewPublicKey={() => setSelectedKey(key)}
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
      {selectedKey && (
        <PublicKeyModal
          keyName={selectedKey.key_name}
          keyAlgorithm={selectedKey.key_algorithm}
          onClose={() => setSelectedKey(null)}
        />
      )}
    </Container>
  );
};
