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
import { Alert, Button, Col, Container, Form, Row, Spinner } from 'react-bootstrap';
import { useNavigate } from 'react-router-dom';

import { useAlerts } from './AlertManager';
import { useFdoOwnerKey } from './hooks/useFdoOwnerKey';
import Icon from './components/Icon';

const KEY_ALGORITHMS = [
  { value: 'es256', label: 'ECDSA P-256 (ES256)' },
  { value: 'es384', label: 'ECDSA P-384 (ES384)' },
  { value: 'rs256', label: 'RSA 2048 (RS256)' },
  { value: 'rs384', label: 'RSA 3072 (RS384)' },
];

export default (): React.ReactElement => {
  const [keyName, setKeyName] = useState('');
  const [keyAlgorithm, setKeyAlgorithm] = useState('es256');
  const [generatedKey, setGeneratedKey] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const { manageOwnerKey, status } = useFdoOwnerKey();
  const [, alertsController] = useAlerts();
  const navigate = useNavigate();

  const isLoading = status === 'loading';

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!keyName || !keyAlgorithm) {
      return;
    }
    try {
      const keyValue = await manageOwnerKey({ action: 'create', keyName, keyAlgorithm });
      setGeneratedKey(keyValue);
    } catch (err: any) {
      alertsController.showError(`Failed to create owner key: ${err.message}`);
    }
  };

  const handleCopy = () => {
    if (!generatedKey) {
      return;
    }
    navigator.clipboard.writeText(generatedKey).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  if (generatedKey) {
    return (
      <Container fluid className="p-3" data-testid="new-fdo-owner-key-page">
        <Row>
          <Col>
            <h2>FDO Owner Key Created</h2>
          </Col>
        </Row>
        <Row className="mt-3">
          <Col md={8} lg={6}>
            <Alert variant="success">
              <Alert.Heading>
                <Icon icon="key" className="me-2" />
                Public key generated successfully
              </Alert.Heading>
              The public key is shown below. You can retrieve it again at any time from the key
              list. The private key is securely managed by OpenBao.
            </Alert>
            <div className="mb-2 d-flex justify-content-between align-items-center">
              <span className="fw-semibold">{keyName}</span>
              <Button
                variant={copied ? 'success' : 'outline-secondary'}
                size="sm"
                onClick={handleCopy}
              >
                <Icon icon="copyPaste" className="me-1" />
                {copied ? 'Copied!' : 'Copy'}
              </Button>
            </div>
            <Form.Control
              as="textarea"
              readOnly
              value={generatedKey}
              rows={8}
              className="font-monospace mb-4"
              style={{ fontSize: '0.8rem' }}
            />
            <Button variant="primary" onClick={() => navigate('/fdo-owner-keys')}>
              Done — go to key list
            </Button>
          </Col>
        </Row>
      </Container>
    );
  }

  return (
    <Container fluid className="p-3" data-testid="new-fdo-owner-key-page">
      <Row>
        <Col>
          <h2>Create FDO Owner Key</h2>
        </Col>
      </Row>
      <Row className="mt-3">
        <Col md={8} lg={6}>
          <Form onSubmit={handleSubmit}>
            <Form.Group className="mb-3" controlId="keyName">
              <Form.Label>Key Name</Form.Label>
              <Form.Control
                type="text"
                placeholder="e.g. device-ecdsa-key"
                value={keyName}
                onChange={(e) => setKeyName(e.target.value)}
                disabled={isLoading}
                required
              />
              <Form.Text className="text-muted">
                Unique identifier for the key stored in OpenBao.
              </Form.Text>
            </Form.Group>

            <Form.Group className="mb-4" controlId="keyAlgorithm">
              <Form.Label>Key Algorithm</Form.Label>
              <Form.Select
                value={keyAlgorithm}
                onChange={(e) => setKeyAlgorithm(e.target.value)}
                disabled={isLoading}
                required
              >
                {KEY_ALGORITHMS.map(({ value, label }) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </Form.Select>
            </Form.Group>

            <div className="d-flex gap-2">
              <Button
                variant="secondary"
                onClick={() => navigate('/fdo-owner-keys')}
                disabled={isLoading}
              >
                Cancel
              </Button>
              <Button variant="primary" type="submit" disabled={isLoading || !keyName}>
                {isLoading ? (
                  <>
                    <Spinner animation="border" size="sm" className="me-2" />
                    Creating...
                  </>
                ) : (
                  <>
                    <Icon icon="add" className="me-2" />
                    Create Key
                  </>
                )}
              </Button>
            </div>
          </Form>
        </Col>
      </Row>
    </Container>
  );
};
