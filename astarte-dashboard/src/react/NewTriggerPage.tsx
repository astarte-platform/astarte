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
import { Button, Container, Row, Spinner } from 'react-bootstrap';
import { AstarteTrigger } from 'astarte-client';

import { useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import TriggerEditor from './components/TriggerEditor';
import BackButton from './ui/BackButton';

export default (): React.ReactElement => {
  const [triggerDraft, setTriggerDraft] = useState<AstarteTrigger | null>(null);
  const [isValidTrigger, setIsValidTrigger] = useState(false);
  const [isInstallingTrigger, setIsInstallingTrigger] = useState(false);
  const [isSourceVisible, setIsSourceVisible] = useState(true);
  const installationAlerts = useAlerts();
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
        installationAlerts.showError(`Could not install trigger: ${err.message}`);
        setIsInstallingTrigger(false);
      });
  }, [astarte.client, triggerDraft, isInstallingTrigger, navigate, installationAlerts.showError]);

  const handleTriggerEditorError = useCallback(
    (message: string) => {
      installationAlerts.showError(message);
    },
    [installationAlerts.showError],
  );

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href="/triggers" />
        Trigger Editor
      </h2>
      <div className="mt-4">
        <installationAlerts.Alerts />
        <TriggerEditor
          realm={astarte.realm}
          onChange={handleTriggerChange}
          onError={handleTriggerEditorError}
          isSourceVisible={isSourceVisible}
          fetchInterfacesName={astarte.client.getInterfaceNames}
          fetchInterfaceMajors={astarte.client.getInterfaceMajors}
          fetchInterface={astarte.client.getInterface}
        />
        <Row className="justify-content-end m-0 mt-3">
          <Button variant="secondary" className="mr-2" onClick={handleToggleSourceVisibility}>
            {isSourceVisible ? 'Hide' : 'Show'} source
          </Button>
          <Button
            variant="primary"
            onClick={handleInstallTrigger}
            disabled={isInstallingTrigger || !isValidTrigger}
          >
            {isInstallingTrigger && (
              <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
            )}
            Install Trigger
          </Button>
        </Row>
      </div>
    </Container>
  );
};
