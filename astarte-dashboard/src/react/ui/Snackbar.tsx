/*
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl

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

import React from 'react';
import { Container, Toast, ToastProps } from 'react-bootstrap';

import { useGlobalAlertsState, IAlert } from '../AlertManager';
import useRelativeTime from '../hooks/useRelativeTime';

type SnackbarAlertProps = ToastProps & {
  alert: IAlert;
};

const SnackbarAlert = ({ alert, ...props }: SnackbarAlertProps) => {
  const alertRelativeTime = useRelativeTime(alert.timestamp);
  return (
    <Toast {...props} onClose={alert.close} className="mx-auto">
      <Toast.Header className={`bg-${alert.options.variant} text-light`}>
        <span className="mx-auto">{alertRelativeTime}</span>
      </Toast.Header>
      <Toast.Body>{alert.message}</Toast.Body>
    </Toast>
  );
};

export default (): React.ReactElement | null => {
  const alerts = useGlobalAlertsState();
  if (!alerts || alerts.length === 0) {
    return null;
  }
  return (
    <Container fluid className="fixed-bottom p-3">
      {alerts.map((alert) => (
        <SnackbarAlert key={alert.id} alert={alert} />
      ))}
    </Container>
  );
};
