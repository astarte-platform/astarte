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
/* eslint-disable camelcase */

import React, { useCallback, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button, Container, Row, Spinner } from 'react-bootstrap';
import { AstarteTriggerDeliveryPolicyDTO } from 'astarte-client/types/dto';

import { AlertsBanner, useAlerts } from './AlertManager';
import { useAstarte } from './AstarteManager';
import BackButton from './ui/BackButton';
import TriggerDeliveryPolicyEditor from './components/TriggerDeliveryPolicyEditor';

const parsedErrorMessage = (status: number): string => {
  switch (status) {
    case 400:
      return 'Bad request';
    case 401:
      return 'Authorization information is missing or invalid.';
    case 403:
      return 'Authorization failed for the resource. This could also result from unexisting resources.';
    case 409:
      return 'A trigger delivery policy with this name already exists.';
    case 422:
      return 'The provided trigger delivery policy is not valid.';
    default:
      return 'Not found';
  }
};

export default (): React.ReactElement => {
  const [policyDraft, setPolicyDraft] = useState<AstarteTriggerDeliveryPolicyDTO>();
  const [isValidPolicy, setIsValidPolicy] = useState(false);
  const [isInstallingPolicy, setIsInstallingPolicy] = useState(false);
  const [isSourceVisible, setIsSourceVisible] = useState(true);
  const [installationAlerts, installationAlertsController] = useAlerts();
  const astarte = useAstarte();
  const navigate = useNavigate();

  const handleToggleSourceVisibility = useCallback(() => {
    setIsSourceVisible((isVisible) => !isVisible);
  }, []);

  const handlePolicyChange = useCallback(
    (updatedPolicy: AstarteTriggerDeliveryPolicyDTO, isValid: boolean) => {
      setPolicyDraft(updatedPolicy);
      setIsValidPolicy(isValid);
    },
    [],
  );

  const handleInstallPolicy = useCallback(() => {
    if (policyDraft == null || isInstallingPolicy) {
      return;
    }
    setIsInstallingPolicy(true);
    astarte.client
      .installTriggerDeliveryPolicy(policyDraft)
      .then(() => {
        navigate({ pathname: '/trigger-delivery-policies' });
      })
      .catch((err) => {
        installationAlertsController.showError(
          `Could not install policy: ${parsedErrorMessage(err.response.status)}`,
        );
        setIsInstallingPolicy(false);
      });
  }, [astarte.client, policyDraft, isInstallingPolicy, navigate, installationAlertsController]);

  return (
    <Container fluid className="p-3">
      <h2>
        <BackButton href="/trigger-delivery-policies" />
        Trigger Delivery Policy Editor
      </h2>
      <TriggerDeliveryPolicyEditor
        isSourceVisible={isSourceVisible}
        onChange={handlePolicyChange}
        isReadOnly={false}
      />
      <div className="mt-4">
        <AlertsBanner alerts={installationAlerts} />
        <Row className="justify-content-end m-0 mt-3">
          <Button variant="secondary" className="me-2" onClick={handleToggleSourceVisibility}>
            {isSourceVisible ? 'Hide' : 'Show'} source
          </Button>
          <Button
            variant="primary"
            onClick={handleInstallPolicy}
            disabled={isInstallingPolicy || !isValidPolicy}
          >
            {isInstallingPolicy && (
              <Spinner as="span" size="sm" animation="border" role="status" className="me-2" />
            )}
            Install Trigger Delivery Policy
          </Button>
        </Row>
      </div>
    </Container>
  );
};
