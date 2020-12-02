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

import { useCallback, useEffect, useRef, useState } from 'react';

type Status = 'loading' | 'ok' | 'err';

type FetchState<Data, FetchParams extends any[]> =
  | {
      status: 'loading';
      value: Data | null;
      error: Error | null;
      refresh: (...params: FetchParams) => Promise<void>;
    }
  | {
      status: 'ok';
      value: Data;
      error: Error | null;
      refresh: (...params: FetchParams) => Promise<void>;
    }
  | {
      status: 'err';
      value: Data | null;
      error: Error;
      refresh: (...params: FetchParams) => Promise<void>;
    };

const useFetch = <Data = any, FetchParams extends any[] = any[]>(
  fetchData: (...params: FetchParams) => Promise<Data>,
  ...initialFetchParams: FetchParams
): FetchState<Data, FetchParams> => {
  if (!fetchData) {
    throw new Error('Invalid fetch method');
  }

  const [status, setStatus] = useState<Status>('loading');
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const isReady = useRef(false);

  const getData = useCallback(
    async (...fetchParams: FetchParams) => {
      setStatus('loading');
      try {
        const fetchedData = await fetchData(...fetchParams);
        if (isReady.current) {
          setData(fetchedData);
          setStatus('ok');
        }
      } catch (err) {
        setError(err);
        setStatus('err');
      }
    },
    [isReady],
  );

  useEffect(() => {
    isReady.current = true;
    getData(...initialFetchParams);
    return () => {
      isReady.current = false;
    };
  }, []);

  if (status === 'err') {
    return {
      status,
      value: data,
      error: error as Error,
      refresh: getData,
    };
  }
  if (status === 'ok') {
    return {
      status,
      value: data as Data,
      error,
      refresh: getData,
    };
  }
  return {
    status,
    value: data,
    error,
    refresh: getData,
  };
};

export default useFetch;
