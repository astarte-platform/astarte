/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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

import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Container, Form, Row, Spinner } from 'react-bootstrap';
import { AstarteInterface } from 'astarte-client';

import { useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import InterfaceEditor from './components/InterfaceEditor';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import ConfirmModal from './components/modals/Confirm';
import BackButton from './ui/BackButton';
import useFetch from './hooks/useFetch';

interface DeleteModalProps {
  interfaceName: string;
  interfaceMajor: number;
  onCancel: () => void;
  onConfirm: () => void;
  isDeletingInterface: boolean;
}

const DeleteModal = ({
  interfaceName,
  interfaceMajor,
  onCancel,
  onConfirm,
  isDeletingInterface,
}: DeleteModalProps) => {
  const [confirmString, setConfirmString] = useState('');

  const canDelete = confirmString === interfaceName;

  return (
    <ConfirmModal
      title="Confirmation Required"
      confirmVariant="danger"
      onCancel={onCancel}
      onConfirm={onConfirm}
      isConfirming={isDeletingInterface}
      disabled={!canDelete}
    >
      <p>
        You are going to remove&nbsp;
        <b>
          {interfaceName} v{interfaceMajor}
        </b>
        . This might cause data loss, removed interfaces cannot be restored. Are you sure?
      </p>
      <p>
        Please type <b>{interfaceName}</b> to proceed.
      </p>
      <Form.Group controlId="confirmInterfaceName">
        <Form.Control
          type="text"
          placeholder="Interface Name"
          value={confirmString}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setConfirmString(e.target.value)}
        />
      </Form.Group>
    </ConfirmModal>
  );
};

export default (): React.ReactElement => {
  const [interfaceDraft, setInterfaceDraft] = useState<AstarteInterface | null>(null);
  const [isValidInterface, setIsValidInterface] = useState(false);
  const [isUpdatingInterface, setIsUpdatingInterface] = useState(false);
  const [isDeletingInterface, setIsDeletingInterface] = useState(false);
  const [isSourceVisible, setIsSourceVisible] = useState(true);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showUpdateModal, setShowUpdateModal] = useState(false);
  const actionAlerts = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();
  const pathParams = useParams();
  const { interfaceName } = pathParams;
  const interfaceMajor = parseInt(pathParams.interfaceMajor, 10);

  const interfaceFetcher = useFetch(() =>
    astarte.client.getInterface({ interfaceName, interfaceMajor }),
  );

  const handleToggleSourceVisibility = useCallback(() => {
    setIsSourceVisible((isVisible) => !isVisible);
  }, []);

  const showConfirmUpdateModal = useCallback(() => {
    setShowUpdateModal(true);
  }, []);

  const hideConfirmUpdateModal = useCallback(() => {
    setShowUpdateModal(false);
  }, []);

  const showConfirmDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, []);

  const hideConfirmDeleteModal = useCallback(() => {
    setShowDeleteModal(false);
  }, []);

  const handleInterfaceChange = useCallback(
    (updatedInterface: AstarteInterface, isValid: boolean) => {
      setInterfaceDraft(updatedInterface);
      setIsValidInterface(isValid);
    },
    [],
  );

  const handleConfirmUpdateInterface = useCallback(() => {
    if (interfaceDraft == null) {
      return;
    }
    setIsUpdatingInterface(true);
    astarte.client
      .updateInterface(new AstarteInterface(interfaceDraft))
      .then(() => {
        actionAlerts.showSuccess('Changes succesfully applied.');
      })
      .catch((err) => {
        actionAlerts.showError(`Could not update interface: ${err.message}`);
      })
      .finally(() => {
        setIsUpdatingInterface(false);
        hideConfirmUpdateModal();
      });
  }, [astarte.client, interfaceDraft, actionAlerts.showSuccess, actionAlerts.showError]);

  const handleConfirmDeleteInterface = useCallback(() => {
    setIsDeletingInterface(true);
    astarte.client
      .deleteInterface(interfaceName, interfaceMajor)
      .then(() => {
        navigate('/interfaces');
      })
      .catch((err) => {
        actionAlerts.showError(`Could not delete interface: ${err.message}`);
        setIsDeletingInterface(false);
        hideConfirmDeleteModal();
      });
  }, [astarte.client, interfaceName, interfaceMajor, navigate, actionAlerts.showError]);

  useEffect(() => {
    if (interfaceFetcher.value != null) {
      setInterfaceDraft(interfaceFetcher.value);
    }
  }, [interfaceFetcher.value]);

  const canUpdateInterface =
    interfaceFetcher.value != null && interfaceDraft != null && isValidInterface;

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href="/interfaces" />
        Interface Editor
      </h2>
      <div className="mt-4">
        <actionAlerts.Alerts />
        <WaitForData
          data={interfaceFetcher.value}
          status={interfaceFetcher.status}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty title="Couldn't load interface properties" onRetry={interfaceFetcher.refresh} />
          }
        >
          {(iface) => (
            <>
              <InterfaceEditor
                initialData={iface}
                onChange={handleInterfaceChange}
                isSourceVisible={isSourceVisible}
                denyMajorChanges
              />
              <Row className="justify-content-end m-3">
                <Button variant="secondary" className="mr-2" onClick={handleToggleSourceVisibility}>
                  {isSourceVisible ? 'Hide' : 'Show'} source
                </Button>
                {iface.major === 0 && (
                  <Button
                    className="mr-2"
                    variant="danger"
                    onClick={isDeletingInterface ? undefined : showConfirmDeleteModal}
                    disabled={isDeletingInterface}
                  >
                    {isDeletingInterface && (
                      <Spinner
                        as="span"
                        size="sm"
                        animation="border"
                        role="status"
                        className="mr-2"
                      />
                    )}
                    Delete interface
                  </Button>
                )}
                <Button
                  variant="primary"
                  onClick={isUpdatingInterface ? undefined : showConfirmUpdateModal}
                  disabled={isUpdatingInterface || !canUpdateInterface}
                >
                  {isUpdatingInterface && (
                    <Spinner
                      as="span"
                      size="sm"
                      animation="border"
                      role="status"
                      className="mr-2"
                    />
                  )}
                  Apply changes
                </Button>
              </Row>
              {showUpdateModal && (
                <ConfirmModal
                  title="Confirmation Required"
                  onCancel={hideConfirmUpdateModal}
                  onConfirm={handleConfirmUpdateInterface}
                  isConfirming={isUpdatingInterface}
                >
                  <p>
                    Update the interface <b>{iface.name}</b>?
                  </p>
                </ConfirmModal>
              )}
              {showDeleteModal && (
                <DeleteModal
                  onCancel={hideConfirmDeleteModal}
                  onConfirm={handleConfirmDeleteInterface}
                  isDeletingInterface={isDeletingInterface}
                  interfaceName={interfaceName}
                  interfaceMajor={interfaceMajor}
                />
              )}
            </>
          )}
        </WaitForData>
      </div>
    </Container>
  );
};
