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

import React, { useCallback, useMemo, useState } from 'react';
import { Col, Container, Row, Spinner } from 'react-bootstrap';
import { Link, useParams } from 'react-router-dom';

import type { AstarteDevice } from 'astarte-client';
import BackButton from '../ui/BackButton';
import Empty from '../components/Empty';
import WaitForData from '../components/WaitForData';
import useFetch from '../hooks/useFetch';
import { useAlerts } from '../AlertManager';
import { useAstarte } from '../AstarteManager';

import DeviceInfoCard from './DeviceInfoCard';
import AliasesCard from './AliasesCard';
import MetadataCard from './MetadataCard';
import GroupsCard from './GroupsCard';
import IntrospectionCard from './IntrospectionCard';
import PreviousInterfacesCard from './PreviousInterfacesCard';
import ExchangedBytesCard from './ExchangedBytesCard';
import DeviceStatusEventsCard from './DeviceStatusEventsCard';
import DeviceLiveEventsCard from './DeviceLiveEventsCard';

import AddToGroupModal from './AddToGroupModal';
import NewAliasModal from './NewAliasModal';
import EditAliasModal from './EditAliasModal';
import NewMetadataModal from './NewMetadataModal';
import EditMetadataModal from './EditMetadataModal';
import ConfirmModal from '../components/modals/Confirm';

type WipeCredentialsModalT = {
  kind: 'wipe_credentials_modal';
  isWipingCredentials: boolean;
};

type AddToGroupModalT = {
  kind: 'add_to_group_modal';
  isAddingToGroup: boolean;
};

type NewAliasModalT = {
  kind: 'new_alias_modal';
  isAddingAlias: boolean;
};

type EditAliasModalT = {
  kind: 'edit_alias_modal';
  isUpdatingAlias: boolean;
  targetAlias: string;
};

type DeleteAliasModalT = {
  kind: 'delete_alias_modal';
  isDeletingAlias: boolean;
  aliasKey: string;
  aliasValue: string;
};

type NewMetadataModalT = {
  kind: 'new_metadata_modal';
  isAddingMetadata: boolean;
};

type EditMetadataModalT = {
  kind: 'edit_metadata_modal';
  isUpdatingMetadata: boolean;
  targetMetadata: string;
};

type DeleteMetadataModalT = {
  kind: 'delete_metadata_modal';
  isDeletingMetadata: boolean;
  metadataKey: string;
  metadataValue: string;
};

type ReregisterDeviceModalT = {
  kind: 'reregister_device_modal';
};

function isWipeCredentialsModal(modal: PageModal): modal is WipeCredentialsModalT {
  return modal.kind === 'wipe_credentials_modal';
}

function isAddToGroupModal(modal: PageModal): modal is AddToGroupModalT {
  return modal.kind === 'add_to_group_modal';
}

function isNewAliasModal(modal: PageModal): modal is NewAliasModalT {
  return modal.kind === 'new_alias_modal';
}

function isEditAliasModal(modal: PageModal): modal is EditAliasModalT {
  return modal.kind === 'edit_alias_modal';
}

function isDeleteAliasModal(modal: PageModal): modal is DeleteAliasModalT {
  return modal.kind === 'delete_alias_modal';
}

function isNewMetadataModal(modal: PageModal): modal is NewMetadataModalT {
  return modal.kind === 'new_metadata_modal';
}

function isEditMetadataModal(modal: PageModal): modal is EditMetadataModalT {
  return modal.kind === 'edit_metadata_modal';
}

function isDeleteMetadataModal(modal: PageModal): modal is DeleteMetadataModalT {
  return modal.kind === 'delete_metadata_modal';
}

function isDeviceReregistrationModal(modal: PageModal): modal is ReregisterDeviceModalT {
  return modal.kind === 'reregister_device_modal';
}

type PageModal =
  | WipeCredentialsModalT
  | AddToGroupModalT
  | NewAliasModalT
  | EditAliasModalT
  | DeleteAliasModalT
  | NewMetadataModalT
  | EditMetadataModalT
  | DeleteMetadataModalT
  | ReregisterDeviceModalT;

export default (): React.ReactElement => {
  const { deviceId } = useParams();
  const astarte = useAstarte();
  const deviceFetcher = useFetch(() => astarte.client.getDeviceInfo(deviceId));
  const groupsFetcher = useFetch(() => astarte.client.getGroupList());
  const devicePageAlers = useAlerts();
  const [activeModal, setActiveModal] = useState<PageModal | null>(null);

  const unjoinedGroups = useMemo(() => {
    if (deviceFetcher.status === 'ok' && groupsFetcher.status === 'ok') {
      const joinedGroups = new Set(deviceFetcher.value.groups);
      return groupsFetcher.value.filter((groupName) => !joinedGroups.has(groupName));
    }
    return [];
  }, [deviceFetcher.status, groupsFetcher.status]);

  const dismissModal = useCallback(() => {
    setActiveModal(null);
  }, []);

  const inhibitDeviceCredentialsRequests = useCallback(
    (inhibit) => {
      astarte.client
        .inhibitDeviceCredentialsRequests(deviceId, inhibit)
        .then(() => {
          deviceFetcher.refresh();
        })
        .catch(() => {
          devicePageAlers.showError(
            `Couldn't ${inhibit ? 'inhibit' : 'enable'} device credentials requests`,
          );
        });
    },
    [astarte.client, deviceId],
  );

  const wipeDeviceCredentials = useCallback(() => {
    astarte.client
      .wipeDeviceCredentials(deviceId)
      .then(() => {
        setActiveModal({ kind: 'reregister_device_modal' });
      })
      .catch(() => {
        devicePageAlers.showError(`Couldn't wipe the device credential secret`);
        dismissModal();
      });
  }, [astarte.client, deviceId]);

  const addDeviceToGroup = useCallback(
    (groupName) => {
      astarte.client
        .addDeviceToGroup({
          groupName,
          deviceId,
        })
        .then(() => {
          deviceFetcher.refresh();
          dismissModal();
        })
        .catch(() => {
          devicePageAlers.showError(`Couldn't add the device to the group`);
          dismissModal();
        });
    },
    [astarte.client],
  );

  const handleAliasUpdate = useCallback(
    (key, value) => {
      astarte.client
        .insertDeviceAlias(deviceId, key, value)
        .then(() => {
          dismissModal();
          deviceFetcher.refresh();
        })
        .catch(() => {
          devicePageAlers.showError(`Couldn't update the device alias`);
          dismissModal();
        });
    },
    [astarte.client, deviceId],
  );

  const handleAliasDeletion = useCallback(
    (key) => {
      astarte.client
        .deleteDeviceAlias(deviceId, key)
        .then(() => {
          dismissModal();
          deviceFetcher.refresh();
        })
        .catch(() => {
          devicePageAlers.showError(`Couldn't delete the device alias`);
          dismissModal();
        });
    },
    [astarte.client, deviceId],
  );

  const handleMetadataUpdate = useCallback(
    (key, value) => {
      astarte.client
        .insertDeviceMetadata(deviceId, key, value)
        .then(() => {
          dismissModal();
          deviceFetcher.refresh();
        })
        .catch(() => {
          devicePageAlers.showError(`Couldn't update the device metadata`);
          dismissModal();
        });
    },
    [astarte.client, deviceId],
  );

  const handleMetadataDeletion = useCallback(
    (key) => {
      astarte.client
        .deleteDeviceMetadata(deviceId, key)
        .then(() => {
          dismissModal();
          deviceFetcher.refresh();
        })
        .catch(() => {
          devicePageAlers.showError(`Couldn't delete the device metadata`);
          dismissModal();
        });
    },
    [astarte.client, deviceId],
  );

  return (
    <Container fluid className="p-3">
      <Row>
        <Col>
          <h2 className="pl-2">
            <BackButton href="/devices" />
            Device
          </h2>
        </Col>
      </Row>
      <devicePageAlers.Alerts />
      <WaitForData
        data={deviceFetcher.value}
        status={deviceFetcher.status}
        fallback={
          <Container fluid className="text-center">
            <Spinner animation="border" role="status" />
          </Container>
        }
        errorFallback={
          <Empty title="Couldn't load device details" onRetry={deviceFetcher.refresh} />
        }
      >
        {(device: AstarteDevice) => {
          const fullInterfaceList = Array.from(device.introspection.values()).concat(
            device.previousInterfaces,
          );

          return (
            <Row>
              <DeviceInfoCard
                device={device}
                onInhibitCredentialsClick={() => inhibitDeviceCredentialsRequests(true)}
                onEnableCredentialsClick={() => inhibitDeviceCredentialsRequests(false)}
                onWipeCredentialsClick={() =>
                  setActiveModal({
                    kind: 'wipe_credentials_modal',
                    isWipingCredentials: false,
                  })
                }
              />
              <AliasesCard
                device={device}
                onNewAliasClick={() =>
                  setActiveModal({
                    kind: 'new_alias_modal',
                    isAddingAlias: false,
                  })
                }
                onEditAliasClick={(alias) =>
                  setActiveModal({
                    kind: 'edit_alias_modal',
                    targetAlias: alias,
                    isUpdatingAlias: false,
                  })
                }
                onRemoveAliasClick={({ key, value }) =>
                  setActiveModal({
                    kind: 'delete_alias_modal',
                    aliasKey: key,
                    aliasValue: value,
                    isDeletingAlias: false,
                  })
                }
              />
              <MetadataCard
                device={device}
                onNewMetadataClick={() =>
                  setActiveModal({
                    kind: 'new_metadata_modal',
                    isAddingMetadata: false,
                  })
                }
                onEditMetadataClick={(metadata) =>
                  setActiveModal({
                    kind: 'edit_metadata_modal',
                    targetMetadata: metadata,
                    isUpdatingMetadata: false,
                  })
                }
                onRemoveMetadataClick={({ key, value }) =>
                  setActiveModal({
                    kind: 'delete_metadata_modal',
                    metadataKey: key,
                    metadataValue: value,
                    isDeletingMetadata: false,
                  })
                }
              />
              <GroupsCard
                device={device}
                showAddToGropButton={unjoinedGroups.length > 0}
                onAddToGroupClick={() =>
                  setActiveModal({
                    kind: 'add_to_group_modal',
                    isAddingToGroup: false,
                  })
                }
              />
              <IntrospectionCard device={device} />
              <PreviousInterfacesCard device={device} />
              {fullInterfaceList.length > 0 && (
                <ExchangedBytesCard astarte={astarte.client} device={device} />
              )}
              <DeviceStatusEventsCard device={device} />
              <DeviceLiveEventsCard astarte={astarte.client} deviceId={device.id} />
            </Row>
          );
        }}
      </WaitForData>
      {activeModal && isWipeCredentialsModal(activeModal) && (
        <ConfirmModal
          title="Wipe Device Credentials"
          confirmLabel="Wipe credentials secret"
          confirmVariant="danger"
          onCancel={dismissModal}
          onConfirm={() => {
            setActiveModal({ ...activeModal, isWipingCredentials: true });
            wipeDeviceCredentials();
          }}
          isConfirming={activeModal.isWipingCredentials}
        >
          <p>
            This will remove the current device credential secret from Astarte, forcing the device
            to register again and store its new credentials secret. Continue?
          </p>
        </ConfirmModal>
      )}
      {activeModal && isAddToGroupModal(activeModal) && (
        <AddToGroupModal
          onCancel={dismissModal}
          onConfirm={(groupName) => {
            setActiveModal({ ...activeModal, isAddingToGroup: true });
            addDeviceToGroup(groupName);
          }}
          groups={unjoinedGroups}
          isAddingToGroup={activeModal.isAddingToGroup}
        />
      )}
      {activeModal && isNewAliasModal(activeModal) && (
        <NewAliasModal
          onCancel={dismissModal}
          onConfirm={({ key, value }) => {
            setActiveModal({ ...activeModal, isAddingAlias: true });
            handleAliasUpdate(key, value);
          }}
          isAddingAlias={activeModal.isAddingAlias}
        />
      )}
      {activeModal && isEditAliasModal(activeModal) && (
        <EditAliasModal
          onCancel={dismissModal}
          onConfirm={({ value }) => {
            setActiveModal({ ...activeModal, isUpdatingAlias: true });
            handleAliasUpdate(activeModal.targetAlias, value);
          }}
          targetAlias={activeModal.targetAlias}
          isUpdatingAlias={activeModal.isUpdatingAlias}
        />
      )}
      {activeModal && isDeleteAliasModal(activeModal) && (
        <ConfirmModal
          title="Delete Alias"
          confirmLabel="Delete"
          confirmVariant="danger"
          onCancel={dismissModal}
          onConfirm={() => {
            setActiveModal({ ...activeModal, isDeletingAlias: true });
            handleAliasDeletion(activeModal.aliasKey);
          }}
          isConfirming={activeModal.isDeletingAlias}
        >
          <p>{`Delete alias "${activeModal.aliasValue}"?`}</p>
        </ConfirmModal>
      )}
      {activeModal && isNewMetadataModal(activeModal) && (
        <NewMetadataModal
          onCancel={dismissModal}
          onConfirm={({ key, value }) => {
            setActiveModal({ ...activeModal, isAddingMetadata: true });
            handleMetadataUpdate(key, value);
          }}
          isAddingMetadata={activeModal.isAddingMetadata}
        />
      )}
      {activeModal && isEditMetadataModal(activeModal) && (
        <EditMetadataModal
          onCancel={dismissModal}
          onConfirm={({ value }) => {
            setActiveModal({ ...activeModal, isUpdatingMetadata: true });
            handleMetadataUpdate(activeModal.targetMetadata, value);
          }}
          targetMetadata={activeModal.targetMetadata}
          isUpdatingMetadata={activeModal.isUpdatingMetadata}
        />
      )}
      {activeModal && isDeleteMetadataModal(activeModal) && (
        <ConfirmModal
          title="Delete Item"
          confirmLabel="Delete"
          confirmVariant="danger"
          onCancel={dismissModal}
          onConfirm={() => {
            setActiveModal({ ...activeModal, isDeletingMetadata: true });
            handleMetadataDeletion(activeModal.metadataKey);
          }}
          isConfirming={activeModal.isDeletingMetadata}
        >
          <p>{`Do you want to delete ${activeModal.metadataKey} from metadata?`}</p>
        </ConfirmModal>
      )}
      {activeModal && isDeviceReregistrationModal(activeModal) && (
        <ConfirmModal title="Device Credentials Wiped" confirmLabel="Ok" onConfirm={dismissModal}>
          <p>
            The device&apos;s credentials secret was wiped from Astarte. You can&nbsp;
            <Link to={`/devices/register?deviceId=${deviceId}`}>click here</Link> to register the
            device again and retrieve its new credentials secret.
          </p>
        </ConfirmModal>
      )}
    </Container>
  );
};
