import { useState, useCallback } from 'react';
import { useAstarte } from '../AstarteManager';

interface RequestState {
  status: 'idle' | 'loading' | 'success' | 'error';
  error: Error | null;
  generatedKey: string | null;
}

export const useFdoOwnerKey = () => {
  const { client } = useAstarte();
  const [state, setState] = useState<RequestState>({
    status: 'idle',
    error: null,
    generatedKey: null,
  });

  const manageOwnerKey = useCallback(
    async (params: {
      action: 'create' | 'upload';
      keyName: string;
      keyAlgorithm?: string;
      keyData?: string;
    }) => {
      setState({ status: 'loading', error: null, generatedKey: null });

      try {
        const response = await client.manageFdoOwnerKey(params);

        setState({ status: 'success', error: null, generatedKey: response });
        return response;
      } catch (err: any) {
        setState({ status: 'error', error: err, generatedKey: null });
        throw err;
      }
    },
    [client],
  );

  return {
    manageOwnerKey,
    status: state.status,
    error: state.error,
    generatedKey: state.generatedKey,
  };
};
