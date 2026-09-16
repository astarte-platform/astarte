import { useState, useCallback } from 'react';
import type { AstarteDevice, AstarteInterfaceDescriptor } from 'astarte-client';
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
      hwId: AstarteDevice['id'],
      keyName: string,
      voucherText: string,
      options?: {
        initialIntrospection?: { [interfaceName: string]: AstarteInterfaceDescriptor };
        keyAlgorithm?: string;
        replacementGuid?: string;
        replacementRvInfo?: string;
        replacementPubKey?: string;
      },
    ) => {
      setState({ status: 'loading', error: null });

      try {
        const response = await client.uploadFdoVoucher(hwId, keyName, voucherText, options);
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
