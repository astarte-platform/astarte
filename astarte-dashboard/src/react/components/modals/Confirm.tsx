/*
   This file is part of Astarte.

   Copyright 2020-2021 Ispirata Srl

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

import React, { useCallback } from 'react';
import { Button, Modal, Spinner } from 'react-bootstrap';
import type { ModalProps } from 'react-bootstrap';

type BoostrapVariant =
  | 'primary'
  | 'secondary'
  | 'success'
  | 'warning'
  | 'danger'
  | 'info'
  | 'light'
  | 'dark'
  | 'link';

interface Props {
  cancelLabel?: string;
  children: React.ReactNode;
  confirmLabel?: string;
  confirmOnEnter?: boolean;
  confirmVariant?: BoostrapVariant;
  disabled?: boolean;
  isConfirming?: boolean;
  onCancel?: () => void;
  onConfirm: () => void;
  size?: ModalProps['size'];
  title: React.ReactNode;
}

const ConfirmModal = ({
  cancelLabel = 'Cancel',
  children,
  confirmLabel = 'Confirm',
  confirmOnEnter = true,
  confirmVariant = 'primary',
  disabled = false,
  isConfirming = false,
  onCancel,
  onConfirm,
  size = 'lg',
  title,
}: Props): React.ReactElement => {
  const handleKeyDown = useCallback((event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key === 'Enter' && confirmOnEnter && !isConfirming) {
      onConfirm();
    }
  }, []);

  return (
    <div onKeyDown={handleKeyDown}>
      <Modal show centered size={size} onHide={onCancel || onConfirm}>
        <Modal.Header closeButton>
          <Modal.Title>{title}</Modal.Title>
        </Modal.Header>
        <Modal.Body>{children}</Modal.Body>
        <Modal.Footer>
          {onCancel && (
            <Button variant="secondary" onClick={onCancel} style={{ minWidth: '5em' }}>
              {cancelLabel}
            </Button>
          )}
          <Button
            variant={confirmVariant}
            disabled={disabled || isConfirming}
            onClick={onConfirm}
            style={{ minWidth: '5em' }}
          >
            {isConfirming && (
              <Spinner className="mr-2" size="sm" animation="border" role="status" />
            )}
            {confirmLabel}
          </Button>
        </Modal.Footer>
      </Modal>
    </div>
  );
};

export default ConfirmModal;
