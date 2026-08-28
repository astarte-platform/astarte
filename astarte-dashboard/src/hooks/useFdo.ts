import { useState, useCallback } from 'react';
import { useAstarte } from '../AstarteManager';

interface UploadState {
  status: 'idle' | 'loading' | 'success' | 'error';
  error: Error | null;
}

export const useFdo = () => {
  const { client } = useAstarte();
  const [state, setState] = useState<UploadState>({ status: 'idle', error: null });
  const [deleteState, setDeleteState] = useState<UploadState>({ status: 'idle', error: null });

  const uploadVoucher = useCallback(
    async (
      keyName: string,
      voucherText: string,
      options?: {
        keyAlgorithm?: string;
        replacementGuid?: string;
        replacementRvInfo?: string;
        replacementPubKey?: string;
      },
    ) => {
      setState({ status: 'loading', error: null });

      try {
        const response = await client.uploadFdoVoucher(keyName, voucherText, options);
        setState({ status: 'success', error: null });
        return response;
      } catch (err: any) {
        setState({ status: 'error', error: err });
        throw err;
      }
    },
    [client],
  );

  const deleteVoucher = useCallback(
    async (guid: string) => {
      setDeleteState({ status: 'loading', error: null });

      try {
        await client.deleteFdoVoucher(guid);
        setDeleteState({ status: 'success', error: null });
      } catch (err: any) {
        setDeleteState({ status: 'error', error: err });
        throw err;
      }
    },
    [client],
  );

  return {
    uploadVoucher,
    status: state.status,
    error: state.error,
    deleteVoucher,
    deleteStatus: deleteState.status,
    deleteError: deleteState.error,
  };
};
