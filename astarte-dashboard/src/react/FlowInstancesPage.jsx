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

import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Button, Modal, OverlayTrigger, Spinner, Table, Tooltip } from 'react-bootstrap';

import { useAlerts } from './AlertManager';
import SingleCardPage from './ui/SingleCardPage';

export default ({ astarte, history }) => {
  const [phase, setPhase] = useState('loading');
  const [instances, setInstances] = useState(null);
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [selectedFlow, setSelectedFlow] = useState(null);
  const [isDeletingFlow, setIsDeletingFlow] = useState(false);
  const deletionAlerts = useAlerts();

  useEffect(() => {
    const handleInstanceResponse = (instance) => {
      setInstances((oldInstances) => oldInstances.concat(instance));
      setPhase('ok');
    };
    const handleFlowResponse = (instanceNames) => {
      if (instanceNames.length === 0) {
        setInstances([]);
        setPhase('ok');
      } else {
        setInstances([]);
        setPhase('loading');
        instanceNames.forEach((name) => {
          astarte.getFlowDetails(name).then(handleInstanceResponse);
        });
      }
      return null;
    };
    const handleFlowError = () => {
      setPhase('err');
    };
    astarte.getFlowInstances().then(handleFlowResponse).catch(handleFlowError);
  }, [astarte, setInstances, setPhase]);

  const confirmDeleteFlow = useCallback(
    (instanceName) => {
      setSelectedFlow(instanceName);
      setIsModalVisible(true);
    },
    [setSelectedFlow, setIsModalVisible],
  );

  const deleteFlow = useCallback(() => {
    const flowName = selectedFlow;
    setIsDeletingFlow(true);
    astarte
      .deleteFlowInstance(flowName)
      .then(() => {
        setIsModalVisible(false);
        setSelectedFlow(null);
        setIsDeletingFlow(false);
        setInstances((oldInstances) =>
          oldInstances.filter((instance) => instance.name !== flowName),
        );
        setPhase('ok');
      })
      .catch((err) => {
        setIsDeletingFlow(false);
        deletionAlerts.showError(`Could not delete flow instance: ${err.message}`);
      });
  }, [
    selectedFlow,
    setIsModalVisible,
    setSelectedFlow,
    setIsDeletingFlow,
    setInstances,
    setPhase,
    deletionAlerts.showError,
  ]);

  const handleModalCancel = useCallback(() => {
    setIsModalVisible(false);
    setSelectedFlow(null);
  }, [setIsModalVisible, setSelectedFlow]);

  let innerHTML;

  switch (phase) {
    case 'ok':
      innerHTML = (
        <>
          <deletionAlerts.Alerts />
          <InstancesTable instances={instances} onDelete={confirmDeleteFlow} />
        </>
      );
      break;

    case 'err':
      innerHTML = <p>Couldn&apos;t load flow instances</p>;
      break;

    default:
      innerHTML = (
        <div>
          <Spinner animation="border" role="status" />;
        </div>
      );
      break;
  }

  return (
    <SingleCardPage title="Running Flows">
      {innerHTML}
      <Button variant="primary" onClick={() => history.push('/pipelines')}>
        New flow
      </Button>
      <ConfirmDeletionModal
        show={isModalVisible}
        flowName={selectedFlow}
        isDeleting={isDeletingFlow}
        onCancel={handleModalCancel}
        onDelete={deleteFlow}
      />
    </SingleCardPage>
  );
};

const InstancesTable = ({ instances, onDelete }) => {
  if (instances.length === 0) {
    return <p>No running flows</p>;
  }
  return (
    <Table responsive>
      <thead>
        <tr>
          <th className="status-column">Status</th>
          <th>Flow Name</th>
          <th>Pipeline</th>
          <th className="action-column">Actions</th>
        </tr>
      </thead>
      <tbody>
        {instances.map((instance) => (
          <TableRow key={instance.name} instance={instance} onDelete={onDelete} />
        ))}
      </tbody>
    </Table>
  );
};

const TableRow = ({ instance, onDelete }) => {
  let colorClass;
  let tooltipText;
  switch (instance.status) {
    case 'running':
      colorClass = 'color-green';
      tooltipText = 'Running';
      break;

    case 'stopped':
      colorClass = 'color-orange';
      tooltipText = 'Stopped';
      break;

    default:
      // assume running
      colorClass = 'color-green';
      tooltipText = 'Running';
      break;
  }
  return (
    <tr>
      <td>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 400 }}
          style={{
            backgroundColor: 'rgba(255, 100, 100, 0.85)',
            padding: '2px 10px',
            color: 'white',
            borderRadius: 3,
          }}
          overlay={<Tooltip>{tooltipText}</Tooltip>}
        >
          <CircleIcon className={colorClass} />
        </OverlayTrigger>
      </td>
      <td>
        <Link to={`/flows/${instance.name}`}>{instance.name}</Link>
      </td>
      <td>{instance.pipeline}</td>
      <td>
        <OverlayTrigger
          placement="left"
          delay={{ show: 150, hide: 400 }}
          style={{
            backgroundColor: 'rgba(255, 100, 100, 0.85)',
            padding: '2px 10px',
            color: 'white',
            borderRadius: 3,
          }}
          overlay={<Tooltip>Delete instance</Tooltip>}
        >
          <Button
            as="i"
            variant="danger"
            className="fas fa-times"
            onClick={() => onDelete(instance.name)}
          />
        </OverlayTrigger>
      </td>
    </tr>
  );
};

const CircleIcon = React.forwardRef((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));

const ConfirmDeletionModal = ({ show, flowName, isDeleting, onCancel, onDelete }) => (
  <div
    onKeyDown={(e) => {
      if (e.key === 'Enter' && !isDeleting) {
        onDelete();
      }
    }}
  >
    <Modal size="sm" show={show} onHide={onCancel}>
      <Modal.Header closeButton>
        <Modal.Title>Warning</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <p>
          Delete flow <b>{flowName}</b>?
        </p>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button variant="danger" onClick={onDelete} disabled={isDeleting}>
          <>
            {isDeleting && <Spinner className="mr-2" size="sm" animation="border" role="status" />}
            Remove
          </>
        </Button>
      </Modal.Footer>
    </Modal>
  </div>
);
