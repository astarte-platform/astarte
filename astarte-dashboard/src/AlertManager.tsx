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

import type { TimestampMilliseconds, UUIDv4 } from './types';

interface HookConfig {
  timeout?: number;
}

interface IAlertOptions {
  onClose?: () => void;
  onOpen?: () => void;
  timeout?: number;
  variant?: 'info' | 'danger' | 'warning' | 'success';
}

interface IAlert {
  id: UUIDv4;
  message: string;
  options: IAlertOptions;
  timestamp: TimestampMilliseconds;
  close: () => void;
}

type IAlertsState = IAlert[];

type AlertsController = {
  close: (alert: IAlert) => void;
  closeAll: () => void;
  showSuccess: (message: string, options?: IAlertOptions) => void;
  showWarning: (message: string, options?: IAlertOptions) => void;
  showError: (message: string, options?: IAlertOptions) => void;
  showInfo: (message: string, options?: IAlertOptions) => void;
};

const useAlerts: (config?: HookConfig) => [IAlertsState, AlertsController] = ({ timeout } = {}) => {
  const timersId = useRef<number[]>([]);
  const [alerts, setAlerts] = useState<IAlert[]>([]);

  useEffect(() => {
    const timersIdRef = timersId.current;
    return () => timersIdRef.forEach(clearTimeout);
  }, []);

  const close = useCallback(
    (alert: IAlert) => {
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
    (message: string, options: IAlertOptions) => {
      const alert: IAlert = {
        id: uuidv4(),
        message,
        options: {
          ...options,
        },
        timestamp: Date.now(),
        close: () => close(alert),
      };
      if (alert.options.timeout) {
        const timerId = window.setTimeout(() => {
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
    (message: string, options: IAlertOptions = {}) => {
      const opts: IAlertOptions = {
        ...options,
        variant: 'success',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show, timeout],
  );

  const showWarning = useCallback(
    (message: string, options: IAlertOptions = {}) => {
      const opts: IAlertOptions = {
        ...options,
        variant: 'warning',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show, timeout],
  );

  const showError = useCallback(
    (message: string, options: IAlertOptions = {}) => {
      const opts: IAlertOptions = {
        ...options,
        variant: 'danger',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show, timeout],
  );

  const showInfo = useCallback(
    (message: string, options: IAlertOptions = {}) => {
      const opts: IAlertOptions = {
        ...options,
        variant: 'info',
        timeout: timeout || 0,
      };
      return show(message, opts);
    },
    [show, timeout],
  );

  const controller = useMemo(
    () => ({
      close,
      closeAll,
      showSuccess,
      showWarning,
      showError,
      showInfo,
    }),
    [close, closeAll, showSuccess, showWarning, showError, showInfo],
  );

  return [alerts, controller];
};

const GlobalAlertsUtilsContext = createContext<React.RefObject<AlertsController> | null>(null);
const GlobalAlertsStateContext = createContext<IAlertsState>([]);

interface GlobalAlertsProviderProps {
  children: React.ReactNode;
}

const GlobalAlertsProvider = ({
  children,
  ...props
}: GlobalAlertsProviderProps): React.ReactElement => {
  const alertUtilsContext = useRef<AlertsController | null>(null);
  const [alerts, alertsController] = useAlerts({
    timeout: 5000,
  });

  alertUtilsContext.current = alertsController;

  return (
    <GlobalAlertsUtilsContext.Provider value={alertUtilsContext} {...props}>
      <GlobalAlertsStateContext.Provider value={alerts} {...props}>
        {children}
      </GlobalAlertsStateContext.Provider>
    </GlobalAlertsUtilsContext.Provider>
  );
};

interface AlertBannerProps {
  alert: IAlert;
}

const AlertBanner = ({ alert }: AlertBannerProps) => {
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
        <div className="col text-end">{alertRelativeTime}</div>
      </Alert>
    </Col>
  );
};

interface AlertsBannerProps {
  alerts: IAlert[];
}

const AlertsBanner = ({ alerts }: AlertsBannerProps) => {
  if (!alerts.length) {
    return null;
  }

  return (
    <Row>
      {alerts.map((alert) => (
        <AlertBanner key={alert.id} alert={alert} />
      ))}
    </Row>
  );
};

const useGlobalAlerts = (): AlertsController => {
  const alertContext = useContext(GlobalAlertsUtilsContext) as React.RefObject<AlertsController>;
  return useMemo(() => alertContext.current, [alertContext]) as AlertsController;
};

const useGlobalAlertsState = (): IAlertsState => useContext(GlobalAlertsStateContext);

export type { IAlert };

export { AlertsBanner, useAlerts, useGlobalAlerts, useGlobalAlertsState };

export default GlobalAlertsProvider;
