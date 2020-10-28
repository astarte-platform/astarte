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

export interface IAlert {
  id: UUIDv4;
  message: string;
  options: IAlertOptions;
  timestamp: TimestampMilliseconds;
  close: () => void;
}

const useAlertsContext = ({ timeout }: HookConfig = {}) => {
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
    [show],
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
    [show],
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
    [show],
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

type IAlertsContext = ReturnType<typeof useAlertsContext>;

type IAlertsUtils = Omit<IAlertsContext, 'alerts'>;
type IAlertsState = IAlertsContext['alerts'];

const GlobalAlertsUtilsContext = createContext<React.RefObject<IAlertsUtils> | null>(null);
const GlobalAlertsStateContext = createContext<IAlertsState>([]);

interface GlobalAlertsProviderProps {
  children: React.ReactNode;
}

const GlobalAlertsProvider = ({
  children,
  ...props
}: GlobalAlertsProviderProps): React.ReactElement => {
  const alertUtilsContext = useRef<IAlertsUtils | null>(null);
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
        <div className="col text-right">{alertRelativeTime}</div>
      </Alert>
    </Col>
  );
};

interface AlertsBannerProps {
  alerts: IAlert[];
}

const AlertsBanner = ({ alerts }: AlertsBannerProps) => (
  <Row>
    {alerts.map((alert) => (
      <AlertBanner key={alert.id} alert={alert} />
    ))}
  </Row>
);

export const useAlerts = (): IAlertsContext & { Alerts: React.FC } => {
  const alertsContext = useAlertsContext();
  const Alerts = () => <AlertsBanner alerts={alertsContext.alerts} />;
  return { ...alertsContext, Alerts };
};

export const useGlobalAlerts = (): IAlertsUtils => {
  const alertContext = useContext(GlobalAlertsUtilsContext) as React.RefObject<IAlertsUtils>;
  return useMemo(() => alertContext.current, [alertContext]) as IAlertsUtils;
};

export const useGlobalAlertsState = (): IAlertsState => useContext(GlobalAlertsStateContext);

export default GlobalAlertsProvider;
