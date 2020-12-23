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

import React, { useState } from 'react';
import { Button, Modal, Spinner } from 'react-bootstrap';

interface AddToGroupModalProps {
  onCancel: () => void;
  onConfirm: (groupName: string) => void;
  groups: string[];
  isAddingToGroup: boolean;
}

const AddToGroupModal = ({
  onCancel,
  onConfirm,
  groups,
  isAddingToGroup,
}: AddToGroupModalProps): React.ReactElement => {
  const [selectedGroup, setSelectedGroup] = useState<string | null>(null);

  return (
    <Modal show centered size="lg" onHide={onCancel}>
      <Modal.Header closeButton>
        <Modal.Title>Select Existing Group</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <ul className="list-unstyled">
          {groups.map((groupName) => (
            <li
              key={groupName}
              className={groupName === selectedGroup ? 'p-2 bg-success text-white' : 'p-2'}
            >
              <span onClick={() => setSelectedGroup(groupName)}>
                <i className="fas fa-plus mr-2" />
                {groupName}
              </span>
            </li>
          ))}
        </ul>
      </Modal.Body>
      <Modal.Footer>
        {onCancel && (
          <Button variant="secondary" onClick={onCancel} style={{ minWidth: '5em' }}>
            Cancel
          </Button>
        )}
        <Button
          variant="primary"
          disabled={isAddingToGroup || selectedGroup === null}
          onClick={() => {
            if (selectedGroup) {
              onConfirm(selectedGroup);
            }
          }}
          style={{ minWidth: '5em' }}
        >
          {isAddingToGroup && (
            <Spinner className="mr-2" size="sm" animation="border" role="status" />
          )}
          Confirm
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default AddToGroupModal;
