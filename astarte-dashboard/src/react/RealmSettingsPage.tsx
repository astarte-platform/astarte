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

import React, { useCallback, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Container, Form, Spinner } from 'react-bootstrap';

import Empty from './components/Empty';
import ConfirmModal from './components/modals/Confirm';
import SingleCardPage from './ui/SingleCardPage';
import { useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';

import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';

type RealmSettings = {
  publicKey: string;
};

interface RealmSettingsFormProps {
  initialValues: RealmSettings;
  onSubmit: (values: RealmSettings) => void;
  isUpdatingSettings: boolean;
}

const RealmSettingsForm = ({
  initialValues,
  onSubmit,
  isUpdatingSettings,
}: RealmSettingsFormProps) => {
  const [values, setValues] = useState(initialValues);
  const canSubmit = values.publicKey.trim() !== '' && values.publicKey !== initialValues.publicKey;

  return (
    <Form>
      <Form.Group controlId="public-key">
        <Form.Label>Public key</Form.Label>
        <Form.Control
          as="textarea"
          className="text-monospace"
          rows={16}
          value={values.publicKey}
          onChange={(e) => setValues({ ...values, publicKey: e.target.value })}
        />
      </Form.Group>
      <Button
        variant="danger"
        disabled={!canSubmit || isUpdatingSettings}
        onClick={() => onSubmit(values)}
      >
        {isUpdatingSettings && (
          <Spinner className="mr-2" size="sm" animation="border" role="status" />
        )}
        Change
      </Button>
    </Form>
  );
};

export default (): React.ReactElement => {
  const [draftRealmSettings, setDraftRealmSettings] = useState<RealmSettings | null>(null);
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [isUpdatingSettings, setIsUpdatingSettings] = useState(false);
  const formAlerts = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();

  const authConfigFetcher = useFetch(astarte.client.getConfigAuth);

  const showModal = useCallback(() => setIsModalVisible(true), [setIsModalVisible]);

  const dismissModal = useCallback(() => setIsModalVisible(false), [setIsModalVisible]);

  const handleFormSubmit = useCallback(
    (realmSettings: RealmSettings) => {
      setDraftRealmSettings(realmSettings);
      showModal();
    },
    [setDraftRealmSettings, showModal],
  );

  const applyNewSettings = useCallback(() => {
    if (draftRealmSettings == null) {
      return;
    }
    setIsUpdatingSettings(true);
    astarte.client
      .updateConfigAuth({ publicKey: draftRealmSettings.publicKey })
      .then(() => {
        navigate('/logout');
      })
      .catch((err) => {
        setIsUpdatingSettings(false);
        dismissModal();
        formAlerts.showError(err.message);
      });
  }, [
    setIsUpdatingSettings,
    astarte.client,
    draftRealmSettings,
    navigate,
    dismissModal,
    formAlerts.showError,
  ]);

  return (
    <SingleCardPage title="Realm Settings">
      <formAlerts.Alerts />
      <WaitForData
        data={authConfigFetcher.value}
        status={authConfigFetcher.status}
        fallback={
          <Container fluid className="text-center">
            <Spinner animation="border" role="status" />
          </Container>
        }
        errorFallback={
          <Empty title="Couldn't load realm settings" onRetry={authConfigFetcher.refresh} />
        }
      >
        {({ publicKey }) => (
          <RealmSettingsForm
            initialValues={{ publicKey }}
            onSubmit={handleFormSubmit}
            isUpdatingSettings={isUpdatingSettings}
          />
        )}
      </WaitForData>
      {isModalVisible && (
        <ConfirmModal
          title="Confirm Public Key Update"
          confirmLabel="Update settings"
          confirmVariant="danger"
          onCancel={dismissModal}
          onConfirm={applyNewSettings}
          isConfirming={isUpdatingSettings}
        >
          <p>
            Realm public key will be changed, users will not be able to make further API calls using
            their current auth token. Confirm?
          </p>
        </ConfirmModal>
      )}
    </SingleCardPage>
  );
};
