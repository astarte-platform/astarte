import React, { useState, useEffect } from 'react';
import {
  Container,
  Row,
  Col,
  Card,
  Form,
  Button,
  Breadcrumb,
  Accordion,
  Spinner,
} from 'react-bootstrap';
import { useFdo } from './hooks/useFdo';
import { useAlerts } from './AlertManager';
import Icon from './components/Icon';
import { useAstarte } from './AstarteManager';

const FdoVoucherPage: React.FC = () => {
  // States to handle the dual upload method (File vs Raw Text)
  const { client } = useAstarte();
  const [uploadMethod, setUploadMethod] = useState<'file' | 'text'>('file');
  const [file, setFile] = useState<File | null>(null);
  const [voucherText, setVoucherText] = useState('');

  // States for Key Selection
  const [keyName, setKeyName] = useState('');
  const [selectedAlgorithm, setSelectedAlgorithm] = useState('');
  const [availableKeys, setAvailableKeys] = useState<{ key_name: string; key_algorithm: string }[]>([]);
  const [isLoadingKeys, setIsLoadingKeys] = useState(false);

  // States for new replacement fields (FDO TO2 settings)
  const [replacementGuid, setReplacementGuid] = useState('');
  const [replacementRvInfo, setReplacementRvInfo] = useState('');
  const [replacementPubKey, setReplacementPubKey] = useState('');

  const [ovGuid, setOvGuid] = useState<string | null>(null);
  const { uploadVoucher, status } = useFdo();
  const [, alertsController] = useAlerts();

  // Helper boolean to check if voucher data is provided
  const isVoucherLoaded =
    (uploadMethod === 'file' && file !== null) ||
    (uploadMethod === 'text' && voucherText.trim() !== '');

  // Effect: Fetch COMPATIBLE keys when the voucher is loaded
  useEffect(() => {
    let isMounted = true;

    const loadCompatibleKeys = async () => {
      if (isVoucherLoaded && availableKeys.length === 0) {
        setIsLoadingKeys(true);

        try {
          // 1. Extract text from the voucher (file or textarea)
          let extractedText = '';
          if (uploadMethod === 'file' && file) {
            extractedText = await new Promise<string>((resolve, reject) => {
              const reader = new FileReader();
              reader.onload = (event) => resolve(event.target?.result as string);
              reader.onerror = (error) => reject(error);
              reader.readAsText(file);
            });
          } else if (uploadMethod === 'text') {
            extractedText = voucherText;
          }

          if (!extractedText) {
            return;
          }

          // 2. Call the new compatible_keys API with the extracted voucher
          const keys = await client.getCompatibleOwnerKeys(extractedText);

          if (isMounted) {
            setAvailableKeys(keys);
            setIsLoadingKeys(false);
          }
        } catch (error) {
          if (isMounted) {
            console.error('Error fetching compatible keys:', error);
            setIsLoadingKeys(false);
          }
        }
      } else if (!isVoucherLoaded && availableKeys.length > 0) {
        // Reset keys if user removes the file
        setAvailableKeys([]);
        setKeyName('');
        setSelectedAlgorithm('');
      }
    };

    loadCompatibleKeys();

    return () => {
      isMounted = false;
    };
  }, [isVoucherLoaded, availableKeys.length, client, file, voucherText, uploadMethod]);

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    setOvGuid(null);

    let finalVoucherText = '';

    // Retrieve the file based on the selected upload method
    if (uploadMethod === 'file') {
      if (!file) {
        return;
      }
      finalVoucherText = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (event) => resolve(event.target?.result as string);
        reader.onerror = (error) => reject(error);
        reader.readAsText(file);
      });
    } else {
      // If the user pastes text, use it directly
      if (!voucherText) {
        return;
      }
      finalVoucherText = voucherText;
    }

    try {
      // Pass the updated parameters to the hook
      const response = await uploadVoucher(keyName, finalVoucherText, {
        keyAlgorithm: selectedAlgorithm || undefined,
        replacementGuid,
        replacementRvInfo,
        replacementPubKey,
      });
      alertsController.showSuccess('Ownership Voucher uploaded successfully!');

      const returnedGuid = response?.data?.guid || response?.guid || 'GUID-NOT-FOUND-IN-RESPONSE';
      setOvGuid(returnedGuid);

      // Reset form fields
      setKeyName('');
      setSelectedAlgorithm('');
      setFile(null);
      setVoucherText('');
      setReplacementGuid('');
      setReplacementRvInfo('');
      setReplacementPubKey('');
      setAvailableKeys([]); // Clear keys to reset the flow
    } catch (err: any) {
      alertsController.showError(`Error: ${err.message}`);
    }
  };

  // Logic to disable the submit button if required fields are missing
  const isSubmitDisabled = status === 'loading' || !isVoucherLoaded || !keyName;

  return (
    <Container fluid className="p-4">
      <Row>
        <Col>
          <Breadcrumb>
            <Breadcrumb.Item href="/">Astarte</Breadcrumb.Item>
            <Breadcrumb.Item active>FDO Management</Breadcrumb.Item>
          </Breadcrumb>
          <h1 className="mb-4">Upload Ownership Voucher</h1>
        </Col>
      </Row>

      <Row>
        <Col md={8} lg={6}>
          <Card className="shadow-sm">
            <Card.Body>
              <Form onSubmit={handleUpload}>
                {/* --- STEP 1: VOUCHER UPLOAD --- */}
                <h5 className="mb-3">1. Provide Voucher Data</h5>

                {/* Upload Method Selection */}
                <Form.Group className="mb-3">
                  <Form.Label className="d-block fw-bold">Voucher Input Method</Form.Label>
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
                      setVoucherText('');
                    }}
                  />
                </Form.Group>

                {/* Conditional Rendering: File Input or Textarea */}
                {uploadMethod === 'file' ? (
                  <Form.Group className="mb-4">
                    <Form.Control
                      type="file"
                      accept=".pem,.txt"
                      onChange={(e: any) => setFile(e.target.files?.[0] || null)}
                    />
                  </Form.Group>
                ) : (
                  <Form.Group className="mb-4">
                    <Form.Control
                      as="textarea"
                      rows={6}
                      placeholder="-----BEGIN OWNERSHIP VOUCHER-----&#10;...&#10;-----END OWNERSHIP VOUCHER-----"
                      value={voucherText}
                      onChange={(e) => setVoucherText(e.target.value)}
                      style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
                    />
                  </Form.Group>
                )}

                <hr className="my-4" />

                {/* --- STEP 2: KEY SELECTION --- */}
                <h5 className="mb-3">
                  2. Select Owner Key
                  {isLoadingKeys && (
                    <Spinner animation="border" size="sm" className="ms-2" variant="primary" />
                  )}
                </h5>
                {(() => {
                  const algorithms = [...new Set(availableKeys.map((k) => k.key_algorithm))];
                  const showAlgorithmPicker = algorithms.length > 1;
                  const filteredKeys = showAlgorithmPicker
                    ? availableKeys.filter((k) => k.key_algorithm === selectedAlgorithm)
                    : availableKeys;
                  const placeholderText = !isVoucherLoaded
                    ? 'Please load a voucher first...'
                    : isLoadingKeys
                      ? 'Fetching available keys...'
                      : '-- Select --';
                  return (
                    <>
                      {showAlgorithmPicker && (
                        <Form.Group className="mb-3">
                          <Form.Label>Algorithm</Form.Label>
                          <Form.Select
                            value={selectedAlgorithm}
                            onChange={(e) => {
                              setSelectedAlgorithm(e.target.value);
                              setKeyName('');
                            }}
                            disabled={!isVoucherLoaded || isLoadingKeys}
                          >
                            <option value="">{placeholderText}</option>
                            {algorithms.map((algo) => (
                              <option key={algo} value={algo}>
                                {algo}
                              </option>
                            ))}
                          </Form.Select>
                        </Form.Group>
                      )}
                      <Form.Group className="mb-4">
                        <Form.Label>Owner Key Name</Form.Label>
                        <Form.Select
                          value={keyName}
                          onChange={(e) => {
                            const name = e.target.value;
                            setKeyName(name);
                            // Always track the algorithm of the selected key so it gets sent in the payload
                            const found = availableKeys.find((k) => k.key_name === name);
                            if (found) { setSelectedAlgorithm(found.key_algorithm); }
                          }}
                          disabled={!isVoucherLoaded || isLoadingKeys || (showAlgorithmPicker && !selectedAlgorithm)}
                        >
                          <option value="">
                            {showAlgorithmPicker && !selectedAlgorithm
                              ? 'Select an algorithm first...'
                              : placeholderText}
                          </option>
                          {filteredKeys.map((k) => (
                            <option key={`${k.key_algorithm}/${k.key_name}`} value={k.key_name}>
                              {k.key_name}
                            </option>
                          ))}
                        </Form.Select>
                        <Form.Text className="text-muted">
                          The alias of the OpenBao key to correlate with this voucher.
                        </Form.Text>
                      </Form.Group>
                    </>
                  );
                })()}

                <hr className="my-4" />

                {/* --- ADVANCED FDO SETTINGS --- */}
                <Accordion className="mb-4">
                  <Accordion.Item eventKey="0">
                    <Accordion.Header>Advanced: Replacement Settings (Optional)</Accordion.Header>
                    <Accordion.Body>
                      <Form.Group className="mb-3">
                        <Form.Label>Replacement GUID</Form.Label>
                        <Form.Control
                          type="text"
                          placeholder="e.g. 123e4567-e89b-12d3-a456-426614174000"
                          value={replacementGuid}
                          onChange={(e) => setReplacementGuid(e.target.value)}
                          disabled={!isVoucherLoaded}
                        />
                      </Form.Group>

                      <Form.Group className="mb-3">
                        <Form.Label>Replacement Rendezvous Info</Form.Label>
                        <Form.Control
                          as="textarea"
                          rows={2}
                          placeholder="Enter RV Info"
                          value={replacementRvInfo}
                          onChange={(e) => setReplacementRvInfo(e.target.value)}
                          disabled={!isVoucherLoaded}
                        />
                      </Form.Group>

                      <Form.Group className="mb-3">
                        <Form.Label>Replacement Public Key</Form.Label>
                        <Form.Control
                          as="textarea"
                          rows={2}
                          placeholder="Enter Public Key"
                          value={replacementPubKey}
                          onChange={(e) => setReplacementPubKey(e.target.value)}
                          disabled={!isVoucherLoaded}
                        />
                      </Form.Group>
                    </Accordion.Body>
                  </Accordion.Item>
                </Accordion>

                {/* --- SUBMIT BUTTON --- */}
                <div className="d-grid mt-4">
                  <Button variant="primary" type="submit" disabled={isSubmitDisabled}>
                    {status === 'loading' ? (
                      'Uploading...'
                    ) : (
                      <>
                        <Icon icon="devices" className="me-2" />
                        Upload and Correlate
                      </>
                    )}
                  </Button>
                </div>

                {/* --- SUCCESS RESULT --- */}
                {ovGuid && (
                  <div className="mt-4 p-3 bg-light border rounded text-center">
                    <h6 className="text-success mb-2">
                      <Icon icon="statusOK" className="me-2" />
                      Voucher Extracted and Saved
                    </h6>
                    <p className="mb-0 text-muted">Device GUID:</p>
                    <p
                      className="mb-0"
                      style={{ fontFamily: 'monospace', fontSize: '1.2em', fontWeight: 'bold' }}
                    >
                      {ovGuid}
                    </p>
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

export default FdoVoucherPage;
