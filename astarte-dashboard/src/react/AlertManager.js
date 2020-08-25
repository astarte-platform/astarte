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
} from "react";
import { createPortal } from "react-dom";
import { v4 as uuidv4 } from "uuid";
import { Alert, Container, Row, Col, Toast } from "react-bootstrap";

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
        if (
          lengthBeforeRemove > filteredAlerts.length &&
          alert.options.onClose
        ) {
          alert.options.onClose();
        }
        return filteredAlerts;
      });
    },
    [setAlerts]
  );

  const closeAll = useCallback(() => {
    alerts.forEach(close);
  }, [alerts, close]);

  const show = useCallback(
    (message = "", options = {}) => {
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
    [close, setAlerts]
  );

  const showSuccess = useCallback(
    (message = "", options = {}) => {
      options.variant = "success";
      options.timeout = timeout || 0;
      return show(message, options);
    },
    [show]
  );

  const showWarning = useCallback(
    (message = "", options = {}) => {
      options.variant = "warning";
      options.timeout = 0;
      return show(message, options);
    },
    [show]
  );

  const showError = useCallback(
    (message = "", options = {}) => {
      options.variant = "danger";
      options.timeout = 0;
      return show(message, options);
    },
    [show]
  );

  const showInfo = useCallback(
    (message = "", options = {}) => {
      options.variant = "info";
      options.timeout = timeout || 0;
      return show(message, options);
    },
    [show]
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

const AlertsBanner = ({ alerts: currentAlerts, setNotifier }) => {
  const [alerts, setAlerts] = useState(currentAlerts);
  useEffect(() => setAlerts(currentAlerts), [setAlerts, currentAlerts]);
  setNotifier && setNotifier(setAlerts);
  if (!alerts || alerts.length === 0) {
    return null;
  }
  return (
    <Row>
      {alerts.map((alert) => (
        <Col key={alert.id} xs={12}>
          <Alert
            variant={alert.options.variant}
            onClose={alert.close}
            dismissible
          >
            {alert.message}
          </Alert>
        </Col>
      ))}
    </Row>
  );
};

const AlertsSnackbar = ({ alerts }) => {
  if (!alerts || alerts.length === 0) {
    return null;
  }
  return (
    <Container fluid className="fixed-bottom p-3">
      {alerts.map((alert) => (
        <Toast key={alert.id} onClose={alert.close} className={`mx-auto`}>
          <Toast.Header className={`bg-${alert.options.variant} text-light`}>
            <span className="mx-auto">
              {new Date(alert.timestamp).toLocaleString()}
            </span>
          </Toast.Header>
          <Toast.Body>{alert.message}</Toast.Body>
        </Toast>
      ))}
    </Container>
  );
};

const GlobalAlertsContext = createContext();

const GlobalAlertsProvider = ({ children, ...props }) => {
  const root = useRef(null);
  const alertContext = useRef(null);
  const {
    alerts,
    close,
    closeAll,
    showSuccess,
    showWarning,
    showError,
    showInfo,
  } = useAlertsContext({ timeout: 5000 });

  useEffect(() => {
    root.current = document.createElement("div");
    root.current.id = "__alert-manager__";
    document.body.appendChild(root.current);
    return () => {
      if (root.current) document.body.removeChild(root.current);
    };
  }, []);

  const Alerts = useMemo(() => {
    return () => <AlertsSnackbar alerts={alerts} />;
  }, [alerts]);

  alertContext.current = {
    close,
    closeAll,
    showSuccess,
    showWarning,
    showError,
    showInfo,
  };

  return (
    <GlobalAlertsContext.Provider value={alertContext} {...props}>
      {children}
      {root.current && createPortal(<Alerts />, root.current)}
    </GlobalAlertsContext.Provider>
  );
};

export const useAlerts = () => {
  const {
    alerts,
    close,
    closeAll,
    showSuccess,
    showWarning,
    showError,
    showInfo,
  } = useAlertsContext();
  const notifyAlerts = useRef(null);

  const setNotifier = useCallback((cb) => {
    notifyAlerts.current = cb;
  }, []);

  const Alerts = useMemo(() => {
    return () => <AlertsBanner alerts={alerts} setNotifier={setNotifier} />;
  }, [alerts]);

  useEffect(() => {
    if (notifyAlerts.current) notifyAlerts.current(alerts);
  }, [alerts]);

  return useMemo(
    () => ({
      Alerts,
      close,
      closeAll,
      showSuccess,
      showWarning,
      showError,
      showInfo,
    }),
    [alerts]
  );
};

export const useGlobalAlerts = () => {
  const alertContext = useContext(GlobalAlertsContext);
  return useMemo(() => {
    return alertContext.current;
  }, [alertContext]);
};

export default GlobalAlertsProvider;
