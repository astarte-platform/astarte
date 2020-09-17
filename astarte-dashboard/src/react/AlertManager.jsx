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

import React, {
  createContext,
  useCallback,
  useEffect,
  useContext,
  useMemo,
  useRef,
  useState,
} from 'react';
import { v4 as uuidv4 } from 'uuid';
import { Alert, Row, Col } from 'react-bootstrap';

import useRelativeTime from './hooks/useRelativeTime';

const useAlertsContext = ({ timeout } = {}) => {
  const timersId = useRef([]);
  const [alerts, setAlerts] = useState([]);

  useEffect(() => {
    const timersIdRef = timersId.current;
    return () => timersIdRef.forEach(clearTimeout);
  }, []);

  const close = useCallback(
    (alert) => {
      setAlerts((currentAlerts) => {
        const lengthBeforeRemove = currentAlerts.length;
        const filteredAlerts = currentAlerts.filter((a) => a.id !== alert.id);
        if (lengthBeforeRemove > filteredAlerts.length && alert.options.onClose) {
          alert.options.onClose();
        }
        return filteredAlerts;
      });
    },
    [setAlerts],
  );

  const closeAll = useCallback(() => {
    alerts.forEach(close);
  }, [alerts, close]);

  const show = useCallback(
    (message = '', options = {}) => {
      const alert = {
        id: uuidv4(),
        message,
        options: {
          ...options,
        },
        timestamp: Date.now(),
        close: () => close(alert),
      };
      if (alert.options.timeout) {
        const timerId = setTimeout(() => {
          close(alert);
          timersId.current.splice(timersId.current.indexOf(timerId), 1);
        }, alert.options.timeout);
        timersId.current.push(timerId);
      }
      setAlerts((state) => state.concat(alert));
      if (alert.options.onOpen) {
        alert.options.onOpen();
      }
      return alert;
    },
    [close, setAlerts],
  );

  const showSuccess = useCallback(
    (message = '', options = {}) => {
      const opts = {
        ...options,
        variant: 'success',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show],
  );

  const showWarning = useCallback(
    (message = '', options = {}) => {
      const opts = {
        ...options,
        variant: 'warning',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show],
  );

  const showError = useCallback(
    (message = '', options = {}) => {
      const opts = {
        ...options,
        variant: 'danger',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show],
  );

  const showInfo = useCallback(
    (message = '', options = {}) => {
      const opts = {
        ...options,
        variant: 'info',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show],
  );

  return {
    alerts,
    close,
    closeAll,
    showSuccess,
    showWarning,
    showError,
    showInfo,
  };
};

const GlobalAlertsUtilsContext = createContext();
const GlobalAlertsStateContext = createContext();

const GlobalAlertsProvider = ({ children, ...props }) => {
  const alertUtilsContext = useRef(null);
  const {
    alerts,
    close,
    closeAll,
    showSuccess,
    showWarning,
    showError,
    showInfo,
  } = useAlertsContext({ timeout: 5000 });

  alertUtilsContext.current = {
    close,
    closeAll,
    showSuccess,
    showWarning,
    showError,
    showInfo,
  };

  return (
    <GlobalAlertsUtilsContext.Provider value={alertUtilsContext} {...props}>
      <GlobalAlertsStateContext.Provider value={alerts} {...props}>
        {children}
      </GlobalAlertsStateContext.Provider>
    </GlobalAlertsUtilsContext.Provider>
  );
};

const AlertBanner = ({ alert }) => {
  const alertRelativeTime = useRelativeTime(alert.timestamp);
  return (
    <Col xs={12}>
      <Alert
        variant={alert.options.variant}
        onClose={alert.close}
        dismissible
        className="d-flex justify-content-between flex-wrap"
      >
        {alert.message}
        <div className="col text-right">{alertRelativeTime}</div>
      </Alert>
    </Col>
  );
};

const AlertsBanner = ({ alerts }) => (
  <Row>
    {alerts.map((alert) => (
      <AlertBanner key={alert.id} alert={alert} />
    ))}
  </Row>
);

export const useAlerts = () => {
  const alertsContext = useAlertsContext();
  alertsContext.Alerts = () => <AlertsBanner alerts={alertsContext.alerts} />;
  return alertsContext;
};

export const useGlobalAlerts = () => {
  const alertContext = useContext(GlobalAlertsUtilsContext);
  return useMemo(() => alertContext.current, [alertContext]);
};

export const useGlobalAlertsState = () => useContext(GlobalAlertsStateContext);

export default GlobalAlertsProvider;
