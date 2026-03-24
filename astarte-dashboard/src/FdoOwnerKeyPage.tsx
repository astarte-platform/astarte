import React, { useState } from 'react';
import { Container, Row, Col, Card, Form, Button, Breadcrumb } from 'react-bootstrap';
import { useFdoOwnerKey } from './hooks/useFdoOwnerKey';
import { useAlerts } from './AlertManager';
import Icon from './components/Icon';

const FdoOwnerKeyPage: React.FC = () => {
  // Common state
  const [keyName, setKeyName] = useState('');
  const [actionType, setActionType] = useState<'create' | 'upload'>('create');

  // State for Create
  const [keyAlgorithm, setKeyAlgorithm] = useState('ecdsa-p256');

  // States for Upload
  const [uploadMethod, setUploadMethod] = useState<'file' | 'text'>('file');
  const [file, setFile] = useState<File | null>(null);
  const [privateKeyText, setPrivateKeyText] = useState('');

  const { manageOwnerKey, status, generatedKey } = useFdoOwnerKey();
  const [, alertsController] = useAlerts();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!keyName) {
      return;
    }

    try {
      if (actionType === 'create') {
        if (!keyAlgorithm) {
          return;
        }
        await manageOwnerKey({ action: 'create', keyName, keyAlgorithm });
        alertsController.showSuccess('Owner Key generated and saved successfully into OpenBao!');
      } else if (actionType === 'upload') {
        let finalKeyText = '';

        if (uploadMethod === 'file') {
          if (!file) {
            return;
          }
          finalKeyText = await new Promise<string>((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (event) => resolve(event.target?.result as string);
            reader.onerror = (error) => reject(error);
            reader.readAsText(file);
          });
        } else {
          if (!privateKeyText) {
            return;
          }
          finalKeyText = privateKeyText;
        }

        await manageOwnerKey({ action: 'upload', keyName, keyData: finalKeyText });
        alertsController.showSuccess('Private Owner Key uploaded successfully into OpenBao!');
      }

      // Reset form on success
      setKeyName('');
      setFile(null);
      setPrivateKeyText('');
      // We keep keyAlgorithm and actionType to what they were for convenience
    } catch (err: any) {
      alertsController.showError(`Error: ${err.message}`);
    }
  };

  const isSubmitDisabled =
    status === 'loading' ||
    !keyName ||
    (actionType === 'upload' && uploadMethod === 'file' && !file) ||
    (actionType === 'upload' && uploadMethod === 'text' && !privateKeyText);

  return (
    <Container fluid className="p-4">
      <Row>
        <Col>
          <Breadcrumb>
            <Breadcrumb.Item href="/">Astarte</Breadcrumb.Item>
            <Breadcrumb.Item active>FDO Management</Breadcrumb.Item>
          </Breadcrumb>
          <h1 className="mb-4">Owner Key Management</h1>
        </Col>
      </Row>

      <Row>
        <Col md={8} lg={6}>
          <Card className="shadow-sm">
            <Card.Body>
              <Form onSubmit={handleSubmit}>
                {/* --- COMMON FIELDS --- */}
                <Form.Group className="mb-4">
                  <Form.Label>Key Name</Form.Label>
                  <Form.Control
                    type="text"
                    placeholder="e.g. device_rsa_key"
                    value={keyName}
                    onChange={(e) => setKeyName(e.target.value)}
                    required
                  />
                  <Form.Text className="text-muted">Key alias inside OpenBao.</Form.Text>
                </Form.Group>

                <hr className="my-4" />

                {/* --- ACTION SELECTION --- */}
                <Form.Group className="mb-4">
                  <Form.Label className="d-block fw-bold">Action</Form.Label>
                  <Form.Check
                    inline
                    type="radio"
                    id="action-create"
                    label="Generate new Key"
                    checked={actionType === 'create'}
                    onChange={() => setActionType('create')}
                  />
                  <Form.Check
                    inline
                    type="radio"
                    id="action-upload"
                    label="Upload existing Private Key"
                    checked={actionType === 'upload'}
                    onChange={() => setActionType('upload')}
                  />
                </Form.Group>

                {/* --- DYNAMIC RENDER BASED ON ACTION --- */}
                {actionType === 'create' ? (
                  <Form.Group className="mb-4">
                    <Form.Label>Key Algorithm</Form.Label>
                    <Form.Select
                      value={keyAlgorithm}
                      onChange={(e) => setKeyAlgorithm(e.target.value)}
                    >
                      <option value="ecdsa-p256">ECDSA P-256 (es256)</option>
                      <option value="ecdsa-p384">ECDSA P-384 (es384)</option>
                      <option value="rsa-2048">RSA 2048 (rs256)</option>
                      <option value="rsa-3072">RSA 3072 (rs384)</option>
                    </Form.Select>
                  </Form.Group>
                ) : (
                  <>
                    <Form.Group className="mb-3">
                      <Form.Label className="d-block">Key Input Method</Form.Label>
                      <Form.Check
                        inline
                        type="radio"
                        id="method-file"
                        label="Upload File (.pem)"
                        checked={uploadMethod === 'file'}
                        onChange={() => {
                          setUploadMethod('file');
                          setFile(null);
                        }}
                      />
                      <Form.Check
                        inline
                        type="radio"
                        id="method-text"
                        label="Paste Raw Text"
                        checked={uploadMethod === 'text'}
                        onChange={() => {
                          setUploadMethod('text');
                          setPrivateKeyText('');
                        }}
                      />
                    </Form.Group>

                    {uploadMethod === 'file' ? (
                      <Form.Group className="mb-4">
                        <Form.Control
                          type="file"
                          accept=".pem,.txt,.key"
                          onChange={(e: any) => setFile(e.target.files?.[0] || null)}
                        />
                      </Form.Group>
                    ) : (
                      <Form.Group className="mb-4">
                        <Form.Control
                          as="textarea"
                          rows={6}
                          placeholder="-----BEGIN PRIVATE KEY-----&#10;...&#10;-----END PRIVATE KEY-----"
                          value={privateKeyText}
                          onChange={(e) => setPrivateKeyText(e.target.value)}
                          style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
                        />
                      </Form.Group>
                    )}
                  </>
                )}

                <div className="d-grid mt-4">
                  <Button variant="primary" type="submit" disabled={isSubmitDisabled}>
                    {status === 'loading' ? (
                      actionType === 'create' ? (
                        'Generating key...'
                      ) : (
                        'Uploading key...'
                      )
                    ) : (
                      <>
                        <Icon
                          icon={actionType === 'create' ? 'settings' : 'devices'}
                          className="me-2"
                        />
                        {actionType === 'create' ? 'Generate Key' : 'Upload Key'}
                      </>
                    )}
                  </Button>
                </div>

                {/* --- SUCCESS BOX (Only shows if there's a returned key payload) --- */}
                {generatedKey && (
                  <div className="mt-4 p-3 bg-light border rounded">
                    <h6 className="text-success mb-2">
                      <Icon icon="statusOK" className="me-2" />
                      {actionType === 'create'
                        ? 'Generated public key'
                        : 'Key uploaded successfully'}
                    </h6>
                    <Form.Control
                      as="textarea"
                      rows={8}
                      readOnly
                      value={generatedKey}
                      style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
                    />
                  </div>
                )}
              </Form>
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </Container>
  );
};

export default FdoOwnerKeyPage;
