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
import { useNavigate } from 'react-router-dom';
import { Button, Container, Spinner, Stack } from 'react-bootstrap';
import { AstarteTrigger } from 'astarte-client';

import { AlertsBanner, useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import TriggerEditor from './components/TriggerEditor';
import BackButton from './ui/BackButton';

export default (): React.ReactElement => {
  const [triggerDraft, setTriggerDraft] = useState<AstarteTrigger | null>(null);
  const [isValidTrigger, setIsValidTrigger] = useState(false);
  const [isInstallingTrigger, setIsInstallingTrigger] = useState(false);
  const [isSourceVisible, setIsSourceVisible] = useState(true);
  const [installationAlerts, installationAlertsController] = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();

  const handleToggleSourceVisibility = useCallback(() => {
    setIsSourceVisible((isVisible) => !isVisible);
  }, []);

  const handleTriggerChange = useCallback((updatedTrigger: AstarteTrigger, isValid: boolean) => {
    setTriggerDraft(updatedTrigger);
    setIsValidTrigger(isValid);
  }, []);

  const handleInstallTrigger = useCallback(() => {
    if (triggerDraft == null || isInstallingTrigger) {
      return;
    }
    setIsInstallingTrigger(true);
    astarte.client
      .installTrigger(new AstarteTrigger(triggerDraft))
      .then(() => {
        navigate({ pathname: '/triggers' });
      })
      .catch((err) => {
        installationAlertsController.showError(`Could not install trigger: ${err.message}`);
        setIsInstallingTrigger(false);
      });
  }, [astarte.client, triggerDraft, isInstallingTrigger, navigate, installationAlertsController]);

  const handleTriggerEditorError = useCallback(
    (message: string) => {
      installationAlertsController.showError(message);
    },
    [installationAlertsController],
  );

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href="/triggers" />
        Trigger Editor
      </h2>
      <Stack gap={3} className="mt-3">
        <AlertsBanner alerts={installationAlerts} />
        <TriggerEditor
          realm={astarte.realm}
          onChange={handleTriggerChange}
          onError={handleTriggerEditorError}
          isSourceVisible={isSourceVisible}
          fetchPoliciesName={astarte.client.getPolicyNames}
          fetchInterfacesName={astarte.client.getInterfaceNames}
          fetchInterfaceMajors={astarte.client.getInterfaceMajors}
          fetchInterface={astarte.client.getInterface}
        />
        <div className="d-flex flex-column flex-md-row justify-content-end gap-3">
          <Button variant="secondary" className="me-2" onClick={handleToggleSourceVisibility}>
            {isSourceVisible ? 'Hide' : 'Show'} source
          </Button>
          <Button
            variant="primary"
            hidden={!astarte.token?.can('realmManagement', 'POST', '/triggers')}
            onClick={handleInstallTrigger}
            disabled={isInstallingTrigger || !isValidTrigger}
          >
            {isInstallingTrigger && (
              <Spinner as="span" size="sm" animation="border" role="status" className="me-2" />
            )}
            Install Trigger
          </Button>
        </div>
      </Stack>
    </Container>
  );
};
