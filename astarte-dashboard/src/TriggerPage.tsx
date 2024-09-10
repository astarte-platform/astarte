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

import React, { useCallback, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Container, Form, Row, Spinner } from 'react-bootstrap';

import { AlertsBanner, useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import Empty from './components/Empty';
import TriggerEditor from './components/TriggerEditor';
import ConfirmModal from './components/modals/Confirm';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import BackButton from './ui/BackButton';

interface DeleteModalProps {
  triggerName: string;
  onCancel: () => void;
  onConfirm: () => void;
  isDeletingTrigger: boolean;
}

const DeleteModal = ({ triggerName, onCancel, onConfirm, isDeletingTrigger }: DeleteModalProps) => {
  const [confirmString, setConfirmString] = useState('');

  const canDelete = confirmString === triggerName;

  return (
    <ConfirmModal
      title="Confirmation Required"
      confirmVariant="danger"
      confirmLabel="Delete"
      onCancel={onCancel}
      onConfirm={onConfirm}
      isConfirming={isDeletingTrigger}
      disabled={!canDelete}
    >
      <p>
        You are going to delete&nbsp;
        <b>{triggerName}</b>. This might cause data loss, deleted triggers cannot be restored. Are
        you sure?
      </p>
      <p>
        Please type <b>{triggerName}</b> to proceed.
      </p>
      <Form.Group controlId="confirmTriggerName">
        <Form.Control
          type="text"
          placeholder="Trigger Name"
          value={confirmString}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setConfirmString(e.target.value)}
        />
      </Form.Group>
    </ConfirmModal>
  );
};

export default (): React.ReactElement => {
  const [isDeletingTrigger, setIsDeletingTrigger] = useState(false);
  const [isSourceVisible, setIsSourceVisible] = useState(true);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletionAlerts, deletionAlertsController] = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();
  const { triggerName = '' } = useParams();
  const { triggerDeliveryPoliciesSupported } = astarte;

  const triggerFetcher = useFetch(() => astarte.client.getTrigger(triggerName));

  const fetchPoliciesName = triggerDeliveryPoliciesSupported
    ? astarte.client.getPolicyNames
    : undefined;

  const handleToggleSourceVisibility = useCallback(() => {
    setIsSourceVisible((isVisible) => !isVisible);
  }, []);

  const showConfirmDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, []);

  const hideConfirmDeleteModal = useCallback(() => {
    setShowDeleteModal(false);
  }, []);

  const handleConfirmDeleteTrigger = useCallback(() => {
    setIsDeletingTrigger(true);
    astarte.client
      .deleteTrigger(triggerName)
      .then(() => {
        navigate('/triggers');
      })
      .catch((err) => {
        deletionAlertsController.showError(`Could not delete trigger: ${err.message}`);
        setIsDeletingTrigger(false);
        hideConfirmDeleteModal();
      });
  }, [astarte.client, triggerName, navigate, deletionAlertsController, hideConfirmDeleteModal]);

  const handleTriggerEditorError = useCallback(
    (message: string) => {
      deletionAlertsController.showError(message);
    },
    [deletionAlertsController],
  );

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href="/triggers" />
        Trigger Editor
      </h2>
      <div className="mt-4">
        <AlertsBanner alerts={deletionAlerts} />
        <WaitForData
          data={triggerFetcher.value}
          status={triggerFetcher.status}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty title="Couldn't load trigger source" onRetry={triggerFetcher.refresh} />
          }
        >
          {(trigger) => (
            <>
              <TriggerEditor
                initialData={trigger}
                isReadOnly
                onError={handleTriggerEditorError}
                isSourceVisible={isSourceVisible}
                fetchPoliciesName={fetchPoliciesName}
                fetchInterfacesName={astarte.client.getInterfaceNames}
                fetchInterfaceMajors={astarte.client.getInterfaceMajors}
                fetchInterface={astarte.client.getInterface}
              />
              <Row className="justify-content-end m-0 mt-3">
                <Button variant="secondary" className="mr-2" onClick={handleToggleSourceVisibility}>
                  {isSourceVisible ? 'Hide' : 'Show'} source
                </Button>
                <Button
                  variant="danger"
                  onClick={showConfirmDeleteModal}
                  disabled={isDeletingTrigger}
                >
                  {isDeletingTrigger && (
                    <Spinner
                      as="span"
                      size="sm"
                      animation="border"
                      role="status"
                      className="mr-2"
                    />
                  )}
                  Delete trigger
                </Button>
              </Row>
            </>
          )}
        </WaitForData>
      </div>
      {showDeleteModal && (
        <DeleteModal
          triggerName={triggerName}
          onCancel={hideConfirmDeleteModal}
          onConfirm={handleConfirmDeleteTrigger}
          isDeletingTrigger={isDeletingTrigger}
        />
      )}
    </Container>
  );
};
