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
import { AlertsBanner, useAlerts } from '../AlertManager';
import { useAstarte } from '../AstarteManager';

import DeviceInfoCard from './DeviceInfoCard';
import AliasesCard from './AliasesCard';
import AttributesCard from './AttributesCard';
import GroupsCard from './GroupsCard';
import IntrospectionCard from './IntrospectionCard';
import PreviousInterfacesCard from './PreviousInterfacesCard';
import ExchangedBytesCard from './ExchangedBytesCard';
import DeviceStatusEventsCard from './DeviceStatusEventsCard';
import DeviceLiveEventsCard from './DeviceLiveEventsCard';

import AddToGroupModal from './AddToGroupModal';
import NewAliasModal from './NewAliasModal';
import EditAliasModal from './EditAliasModal';
import NewAttributeModal from './NewAttributeModal';
import EditAttributeModal from './EditAttributeModal';
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

type NewAttributeModalT = {
  kind: 'new_attribute_modal';
  isAddingAttribute: boolean;
};

type EditAttributeModalT = {
  kind: 'edit_attribute_modal';
  isUpdatingAttribute: boolean;
  targetAttribute: string;
};

type DeleteAttributeModalT = {
  kind: 'delete_attribute_modal';
  isDeletingAttribute: boolean;
  attributeKey: string;
  attributeValue: string;
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

function isNewAttributeModal(modal: PageModal): modal is NewAttributeModalT {
  return modal.kind === 'new_attribute_modal';
}

function isEditAttributeModal(modal: PageModal): modal is EditAttributeModalT {
  return modal.kind === 'edit_attribute_modal';
}

function isDeleteAttributeModal(modal: PageModal): modal is DeleteAttributeModalT {
  return modal.kind === 'delete_attribute_modal';
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
  | NewAttributeModalT
  | EditAttributeModalT
  | DeleteAttributeModalT
  | ReregisterDeviceModalT;

export default (): React.ReactElement => {
  const { deviceId } = useParams();
  const astarte = useAstarte();
  const deviceFetcher = useFetch(() => astarte.client.getDeviceInfo(deviceId));
  const groupsFetcher = useFetch(() => astarte.client.getGroupList());
  const [devicePageAlers, devicePageAlersController] = useAlerts();
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
          devicePageAlersController.showError(
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
        devicePageAlersController.showError(`Couldn't wipe the device credential secret`);
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
          devicePageAlersController.showError(`Couldn't add the device to the group`);
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
          devicePageAlersController.showError(`Couldn't update the device alias`);
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
          devicePageAlersController.showError(`Couldn't delete the device alias`);
          dismissModal();
        });
    },
    [astarte.client, deviceId],
  );

  const handleAttributeUpdate = useCallback(
    (key, value) => {
      astarte.client
        .insertDeviceAttribute(deviceId, key, value)
        .then(() => {
          dismissModal();
          deviceFetcher.refresh();
        })
        .catch(() => {
          devicePageAlersController.showError(`Couldn't update the device attribute`);
          dismissModal();
        });
    },
    [astarte.client, deviceId],
  );

  const handleAttributeDeletion = useCallback(
    (key) => {
      astarte.client
        .deleteDeviceAttribute(deviceId, key)
        .then(() => {
          dismissModal();
          deviceFetcher.refresh();
        })
        .catch(() => {
          devicePageAlersController.showError(`Couldn't delete the device attribute`);
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
      <AlertsBanner alerts={devicePageAlers} />
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
              <AttributesCard
                device={device}
                onNewAttributeClick={() =>
                  setActiveModal({
                    kind: 'new_attribute_modal',
                    isAddingAttribute: false,
                  })
                }
                onEditAttributeClick={(attribute) =>
                  setActiveModal({
                    kind: 'edit_attribute_modal',
                    targetAttribute: attribute,
                    isUpdatingAttribute: false,
                  })
                }
                onRemoveAttributeClick={({ key, value }) =>
                  setActiveModal({
                    kind: 'delete_attribute_modal',
                    attributeKey: key,
                    attributeValue: value,
                    isDeletingAttribute: false,
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
      {activeModal && isNewAttributeModal(activeModal) && (
        <NewAttributeModal
          onCancel={dismissModal}
          onConfirm={({ key, value }) => {
            setActiveModal({ ...activeModal, isAddingAttribute: true });
            handleAttributeUpdate(key, value);
          }}
          isAddingAttribute={activeModal.isAddingAttribute}
        />
      )}
      {activeModal && isEditAttributeModal(activeModal) && (
        <EditAttributeModal
          onCancel={dismissModal}
          onConfirm={({ value }) => {
            setActiveModal({ ...activeModal, isUpdatingAttribute: true });
            handleAttributeUpdate(activeModal.targetAttribute, value);
          }}
          targetAttribute={activeModal.targetAttribute}
          isUpdatingAttribute={activeModal.isUpdatingAttribute}
        />
      )}
      {activeModal && isDeleteAttributeModal(activeModal) && (
        <ConfirmModal
          title="Delete Attribute"
          confirmLabel="Delete"
          confirmVariant="danger"
          onCancel={dismissModal}
          onConfirm={() => {
            setActiveModal({ ...activeModal, isDeletingAttribute: true });
            handleAttributeDeletion(activeModal.attributeKey);
          }}
          isConfirming={activeModal.isDeletingAttribute}
        >
          <p>{`Do you want to delete ${activeModal.attributeKey} from attributes?`}</p>
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
