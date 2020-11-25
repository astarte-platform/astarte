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

import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Form, Spinner } from 'react-bootstrap';
import AstarteClient from 'astarte-client';

import ConfirmModal from './components/modals/Confirm';
import SingleCardPage from './ui/SingleCardPage';
import { useAlerts } from './AlertManager';

interface Props {
  astarte: AstarteClient;
}

export default ({ astarte }: Props): React.ReactElement => {
  const [phase, setPhase] = useState<'ok' | 'loading' | 'err'>('loading');
  const [userPublicKey, setUserPublicKey] = useState('');
  const [draftPublicKey, setDraftPublicKey] = useState('');
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [isUpdatingSettings, setIsUpdatingSettings] = useState(false);
  const formAlerts = useAlerts();
  const navigate = useNavigate();

  const showModal = useCallback(() => setIsModalVisible(true), [setIsModalVisible]);

  const dismissModal = useCallback(() => setIsModalVisible(false), [setIsModalVisible]);

  const applyNewSettings = useCallback(() => {
    setIsUpdatingSettings(true);
    astarte
      .updateConfigAuth({ publicKey: draftPublicKey })
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
    astarte,
    draftPublicKey,
    navigate,
    dismissModal,
    formAlerts.showError,
  ]);

  useEffect(() => {
    astarte
      .getConfigAuth()
      .then(({ publicKey }) => {
        setUserPublicKey(publicKey);
        setDraftPublicKey(publicKey);
        setPhase('ok');
      })
      .catch(() => setPhase('err'));
  }, [astarte, setUserPublicKey, setDraftPublicKey, setPhase]);

  const canUpdatePublicKey = draftPublicKey !== userPublicKey && draftPublicKey.trim() !== '';
  let innerHTML;

  switch (phase) {
    case 'ok':
      innerHTML = (
        <>
          <formAlerts.Alerts />
          <Form>
            <Form.Group controlId="public-key">
              <Form.Label>Public key</Form.Label>
              <Form.Control
                as="textarea"
                className="text-monospace"
                rows={16}
                value={draftPublicKey}
                onChange={(e) => setDraftPublicKey(e.target.value)}
              />
            </Form.Group>
            <Button
              variant="danger"
              disabled={!canUpdatePublicKey || isUpdatingSettings}
              onClick={showModal}
            >
              {isUpdatingSettings && (
                <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
              )}
              Apply
            </Button>
          </Form>
        </>
      );
      break;

    case 'err':
      innerHTML = <p>Couldn&apos;t load realm settings</p>;
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
    <SingleCardPage title="Realm Settings">
      {innerHTML}
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
