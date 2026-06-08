/* eslint-disable camelcase */
/*
   This file is part of Astarte.

   Copyright 2023 SECO Mind Srl

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
import { Button, Container, Form, Spinner, Stack } from 'react-bootstrap';

import { AstarteTriggerDeliveryPolicyDTO } from 'astarte-client/types/dto';
import { AlertsBanner, useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import Empty from './components/Empty';
import TriggerDeliveryPolicyEditor from './components/TriggerDeliveryPolicyEditor';
import ConfirmModal from './components/modals/Confirm';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';
import BackButton from './ui/BackButton';

const parsedErrorMessage = (status: number): string => {
  switch (status) {
    case 401:
      return 'Unauthorized.';
    case 403:
      return 'Forbidden.';
    case 409:
      return 'Cannot delete policy as it is being currently used by triggers.';
    default:
      return 'Not found';
  }
};

interface DeleteModalProps {
  policyName: string;
  onCancel: () => void;
  onConfirm: () => void;
  isDeletingPolicy: boolean;
}

const DeleteModal = ({ policyName, onCancel, onConfirm, isDeletingPolicy }: DeleteModalProps) => {
  const [confirmString, setConfirmString] = useState('');

  const canDelete = confirmString === policyName;

  return (
    <ConfirmModal
      title="Confirmation Required"
      confirmVariant="danger"
      confirmLabel="Delete"
      onCancel={onCancel}
      onConfirm={onConfirm}
      isConfirming={isDeletingPolicy}
      disabled={!canDelete}
    >
      <p>
        You are going to delete&nbsp;
        <b>{policyName}</b>. This might cause data loss, deleted trigger delivery policy cannot be
        restored. Are you sure?
      </p>
      <p>
        Please type <b>{policyName}</b> to proceed.
      </p>
      <Form.Group controlId="confirmPolicyName">
        <Form.Control
          type="text"
          placeholder="Policy Name"
          value={confirmString}
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setConfirmString(e.target.value)}
        />
      </Form.Group>
    </ConfirmModal>
  );
};

export default (): React.ReactElement => {
  const [isDeletingPolicy, setIsDeletingPolicy] = useState(false);
  const [isSourceVisible, setIsSourceVisible] = useState(true);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletionAlerts, deletionAlertsController] = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();
  const { policyName = '' } = useParams();

  const policyFetcher = useFetch(() => astarte.client.getTriggerDeliveryPolicy(policyName));

  const checkData = (data: AstarteTriggerDeliveryPolicyDTO | null) => {
    const newData: AstarteTriggerDeliveryPolicyDTO | null = data;
    if (data?.event_ttl === null) {
      delete newData?.event_ttl;
    }
    if (data?.retry_times === null || data?.retry_times === 0) {
      delete newData?.retry_times;
    }
    return newData;
  };

  const handleToggleSourceVisibility = useCallback(() => {
    setIsSourceVisible((isVisible) => !isVisible);
  }, []);

  const showConfirmDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, []);

  const hideConfirmDeleteModal = useCallback(() => {
    setShowDeleteModal(false);
  }, []);

  const handleConfirmDeletePolicy = useCallback(() => {
    setIsDeletingPolicy(true);
    astarte.client
      .deleteTriggerDeliveryPolicy(policyName)
      .then(() => {
        navigate('/trigger-delivery-policies');
      })
      .catch((err) => {
        deletionAlertsController.showError(
          `Could not delete policy: ${parsedErrorMessage(err.response.status)}`,
        );
        setIsDeletingPolicy(false);
        hideConfirmDeleteModal();
      });
  }, [astarte.client, policyName, navigate, deletionAlertsController, hideConfirmDeleteModal]);

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href="/trigger-delivery-policies" />
        Trigger Delivery Policy Editor
      </h2>
      <Stack gap={3} className="mt-3">
        <AlertsBanner alerts={deletionAlerts} />
        <WaitForData
          data={checkData(policyFetcher.value)}
          status={policyFetcher.status}
          fallback={
            <Container fluid className="text-center">
              <Spinner animation="border" role="status" />
            </Container>
          }
          errorFallback={
            <Empty
              title="Couldn't load trigger delivery policy source"
              onRetry={policyFetcher.refresh}
            />
          }
        >
          {(policy) => (
            <>
              <TriggerDeliveryPolicyEditor
                initialData={policy}
                isReadOnly
                isSourceVisible={isSourceVisible}
              />
              <div className="d-flex flex-column flex-md-row justify-content-end gap-3">
                <Button variant="secondary" onClick={handleToggleSourceVisibility}>
                  {isSourceVisible ? 'Hide' : 'Show'} source
                </Button>
                <Button
                  variant="danger"
                  onClick={showConfirmDeleteModal}
                  hidden={
                    !astarte.token?.can('realmManagement', 'DELETE', `/policies/${policyName}`)
                  }
                  disabled={isDeletingPolicy}
                >
                  {isDeletingPolicy && (
                    <Spinner
                      as="span"
                      size="sm"
                      animation="border"
                      role="status"
                      className="me-2"
                    />
                  )}
                  Delete Trigger Delivery Policy
                </Button>
              </div>
            </>
          )}
        </WaitForData>
      </Stack>
      {showDeleteModal && (
        <DeleteModal
          policyName={policyName}
          onCancel={hideConfirmDeleteModal}
          onConfirm={handleConfirmDeletePolicy}
          isDeletingPolicy={isDeletingPolicy}
        />
      )}
    </Container>
  );
};
