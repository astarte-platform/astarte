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

import { useCallback, useEffect, useState } from 'react';
import type { ChartProvider, ChartData, ChartDataWrapper, ChartDataKind } from 'astarte-charts';

type Status = 'initial' | 'loading' | 'loaded';

type DataFetcher<Data> =
  | {
      status: 'initial';
      data: null;
      refresh: () => Promise<void>;
    }
  | {
      status: 'loading';
      data: Data | null;
      refresh: () => Promise<void>;
    }
  | {
      status: 'loaded';
      data: Data | null;
      refresh: () => Promise<void>;
    };

export const useChartProviders = <
  DataWrapper extends ChartDataWrapper,
  DataKind extends ChartDataKind,
>(params: {
  providers: ChartProvider<DataWrapper, DataKind>[];
  onError?: (error: Error) => void;
  refreshInterval?: number;
}): DataFetcher<(ChartData<DataWrapper, DataKind> | null)[]> => {
  const [status, setStatus] = useState<Status>('initial');
  const [data, setData] = useState<(ChartData<DataWrapper, DataKind> | null)[] | null>(null);

  const fetchData = useCallback(async () => {
    setStatus('loading');
    try {
      const providersData = await Promise.all(
        params.providers.map((provider) => provider.getData()),
      );
      setData(providersData);
    } catch (err: any) {
      if (params.onError) {
        params.onError(err);
      }
    } finally {
      setStatus('loaded');
    }
  }, [params.providers]);

  useEffect(() => {
    fetchData();
    if (params.refreshInterval) {
      const fetchDataInterval = setInterval(fetchData, params.refreshInterval);
      return () => clearInterval(fetchDataInterval);
    }
    return () => {};
  }, [fetchData, params.refreshInterval]);

  if (status === 'initial') {
    return {
      status,
      data: data as null,
      refresh: fetchData,
    };
  }
  return {
    status,
    data,
    refresh: fetchData,
  };
};
