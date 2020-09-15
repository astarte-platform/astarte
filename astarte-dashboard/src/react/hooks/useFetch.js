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

const useFetch = (fetchData) => {
  if (!fetchData) {
    throw new Error('Invalid fetch method');
  }

  const [data, setData] = useState(null);
  const [status, setStatus] = useState('loading');
  const [error, setError] = useState({});
  const isReady = useRef(false);

  const getData = useCallback(async () => {
    setStatus('loading');
    try {
      const response = await fetchData();
      if (isReady.current) {
        setData(response.data);
        setStatus('ok');
      }
    } catch (err) {
      setError(err);
      setStatus('err');
    }
  }, [isReady]);

  useEffect(() => {
    isReady.current = true;
    getData();
    return () => {
      isReady.current = false;
    };
  }, []);

  return {
    status,
    value: data,
    error,
    refresh: getData,
  };
};

export default useFetch;
