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

import { useCallback, useEffect, useState } from 'react';
import type {
  AstarteChartProvider,
  AstarteChartSingleValue,
  AstarteChartListValue,
} from 'astarte-charts';

type Status = 'loading' | 'ok' | 'error';

type DataFetcher<Data> =
  | {
      status: 'loading';
      data: Data | null;
      error: Error | null;
      refresh: () => Promise<void>;
    }
  | {
      status: 'ok';
      data: Data;
      error: Error | null;
      refresh: () => Promise<void>;
    }
  | {
      status: 'error';
      data: Data | null;
      error: Error;
      refresh: () => Promise<void>;
    };

export const useChartProviders = <
  AstarteChartProviderValue extends null | AstarteChartSingleValue | AstarteChartListValue
>(
  providers: AstarteChartProvider<AstarteChartProviderValue>[],
  refreshInterval = 0,
): DataFetcher<AstarteChartProviderValue[]> => {
  const [status, setStatus] = useState<Status>('loading');
  const [data, setData] = useState<AstarteChartProviderValue[] | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const fetchData = useCallback(async () => {
    setStatus('loading');
    try {
      const providersData = await Promise.all(providers.map((provider) => provider.getData()));
      setData(providersData);
      setStatus('ok');
    } catch (err) {
      setError(err);
      setStatus('error');
    }
  }, [providers]);

  useEffect(() => {
    fetchData();
    if (refreshInterval) {
      const fetchDataInterval = setInterval(fetchData, refreshInterval);
      return () => clearInterval(fetchDataInterval);
    }
    return () => {};
  }, [fetchData, refreshInterval]);

  if (status === 'error') {
    return {
      status,
      data,
      error: error as Error,
      refresh: fetchData,
    };
  }
  if (status === 'ok') {
    return {
      status,
      data: data as AstarteChartProviderValue[],
      error,
      refresh: fetchData,
    };
  }
  return {
    status,
    data,
    error,
    refresh: fetchData,
  };
};
