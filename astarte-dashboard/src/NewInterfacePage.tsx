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
import { Button, Container, Spinner, Stack } from 'react-bootstrap';
import { AstarteInterface } from 'astarte-client';
import _ from 'lodash';

import { AlertsBanner, useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import InterfaceEditor from './components/InterfaceEditor';
import ConfirmModal from './components/modals/Confirm';
import BackButton from './ui/BackButton';

interface InstallModalProps {
  interfaceName: string;
  isDraft: boolean;
  onCancel: () => void;
  onConfirm: () => void;
  isInstallingInterface: boolean;
}

const InstallModal = ({
  interfaceName,
  isDraft,
  onCancel,
  onConfirm,
  isInstallingInterface,
}: InstallModalProps) => (
  <ConfirmModal
    title="Confirmation Required"
    confirmLabel="Install"
    onCancel={onCancel}
    onConfirm={onConfirm}
    isConfirming={isInstallingInterface}
  >
    <p>
      You are about to install the interface <b>{interfaceName}</b>.
    </p>
    {isDraft ? (
      <p>
        As its major version is 0, this is a draft interface, which can be deleted.
        <br />
        In such a case, any data sent through this interface will be lost.
        <br />
        Draft Interfaces should be used for development and testing purposes only.
      </p>
    ) : (
      <p>
        Interface major is greater than zero, that means you will not be able to change already
        installed mappings.
      </p>
    )}
    <p>Are you sure you want to continue?</p>
  </ConfirmModal>
);

export default (): React.ReactElement => {
  const [interfaceDraft, setInterfaceDraft] = useState<AstarteInterface | null>(null);
  const [isValidInterface, setIsValidInterface] = useState(false);
  const [isInstallingInterface, setIsInstallingInterface] = useState(false);
  const [showInstallModal, setShowInstallModal] = useState(false);
  const [isSourceVisible, setIsSourceVisible] = useState(true);
  const [installationAlerts, installationAlertsController] = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();

  const handleToggleSourceVisibility = useCallback(() => {
    setIsSourceVisible((isVisible) => !isVisible);
  }, []);

  const handleInterfaceChange = useCallback(
    (updatedInterface: AstarteInterface, isValid: boolean) => {
      setInterfaceDraft(updatedInterface);
      setIsValidInterface(isValid);
    },
    [],
  );

  const showConfirmInstallModal = useCallback(() => {
    setShowInstallModal(true);
  }, []);

  const hideConfirmInstallModal = useCallback(() => {
    setShowInstallModal(false);
  }, []);

  const handleConfirmInstallInterface = useCallback(() => {
    if (interfaceDraft == null || isInstallingInterface) {
      return;
    }
    setIsInstallingInterface(true);
    astarte.client
      .installInterface(new AstarteInterface(interfaceDraft))
      .then(() => {
        navigate({ pathname: '/interfaces' });
      })
      .catch((err) => {
        installationAlertsController.showError(`Could not install interface: ${err.message}`);
        setIsInstallingInterface(false);
        hideConfirmInstallModal();
      });
  }, [
    astarte.client,
    interfaceDraft,
    isInstallingInterface,
    navigate,
    hideConfirmInstallModal,
    installationAlertsController,
  ]);

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href="/interfaces" />
        Interface Editor
      </h2>
      <Stack gap={3} className="mt-3">
        <AlertsBanner alerts={installationAlerts} />
        <InterfaceEditor onChange={handleInterfaceChange} isSourceVisible={isSourceVisible} />
        <div className="d-flex flex-column flex-md-row justify-content-end gap-3">
          <Button variant="secondary" onClick={handleToggleSourceVisibility}>
            {isSourceVisible ? 'Hide' : 'Show'} source
          </Button>
          <Button
            variant="primary"
            onClick={showConfirmInstallModal}
            disabled={isInstallingInterface || !isValidInterface}
          >
            {isInstallingInterface && (
              <Spinner as="span" size="sm" animation="border" role="status" />
            )}
            Install interface
          </Button>
        </div>
      </Stack>
      {showInstallModal && (
        <InstallModal
          onCancel={hideConfirmInstallModal}
          onConfirm={handleConfirmInstallInterface}
          isInstallingInterface={isInstallingInterface}
          interfaceName={_.get(interfaceDraft, 'name', '')}
          isDraft={_.get(interfaceDraft, 'major', 0) === 0}
        />
      )}
    </Container>
  );
};
