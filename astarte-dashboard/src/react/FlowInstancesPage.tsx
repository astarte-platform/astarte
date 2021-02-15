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

import React, { useCallback, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button, Container, OverlayTrigger, Spinner, Table, Tooltip } from 'react-bootstrap';
import AstarteClient from 'astarte-client';
import type { AstarteFlow } from 'astarte-client';

import { useAlerts } from './AlertManager';
import ConfirmModal from './components/modals/Confirm';
import SingleCardPage from './ui/SingleCardPage';
import Empty from './components/Empty';
import WaitForData from './components/WaitForData';
import useFetch from './hooks/useFetch';

const CircleIcon = React.forwardRef<HTMLElement, React.HTMLProps<HTMLElement>>((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));

interface TableRowProps {
  instance: AstarteFlow;
  onDelete: (instance: AstarteFlow) => void;
}

const TableRow = ({ instance, onDelete }: TableRowProps): React.ReactElement => (
  <tr>
    <td>
      <OverlayTrigger
        placement="right"
        delay={{ show: 150, hide: 400 }}
        overlay={<Tooltip id={`flow-state-${instance.name}`}>Running</Tooltip>}
      >
        <CircleIcon className="color-green" />
      </OverlayTrigger>
    </td>
    <td>
      <Link to={`/flows/${instance.name}/edit`}>{instance.name}</Link>
    </td>
    <td>{instance.pipeline}</td>
    <td>
      <OverlayTrigger
        placement="left"
        delay={{ show: 150, hide: 400 }}
        overlay={<Tooltip id={`delete-flow-${instance.name}`}>Delete instance</Tooltip>}
      >
        <Button
          as="i"
          variant="danger"
          className="fas fa-times"
          onClick={() => onDelete(instance)}
        />
      </OverlayTrigger>
    </td>
  </tr>
);

interface InstancesTableProps {
  instances: AstarteFlow[];
  onDelete: (instance: AstarteFlow) => void;
}

const InstancesTable = ({ instances, onDelete }: InstancesTableProps): React.ReactElement => {
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

interface Props {
  astarte: AstarteClient;
}

export default ({ astarte }: Props): React.ReactElement => {
  const [flowToConfirmDelete, setFlowToConfirmDelete] = useState<AstarteFlow['name'] | null>(null);
  const [isDeletingFlow, setIsDeletingFlow] = useState(false);
  const deletionAlerts = useAlerts();
  const navigate = useNavigate();

  const fetchInstances = useCallback(async (): Promise<AstarteFlow[]> => {
    const instanceNames = await astarte.getFlowInstances();
    const instances = await Promise.all(instanceNames.map((name) => astarte.getFlowDetails(name)));
    return instances;
  }, [astarte]);

  const instancesFetcher = useFetch(fetchInstances);

  const handleDeleteFlow = useCallback(
    (instance: AstarteFlow) => {
      setFlowToConfirmDelete(instance.name);
    },
    [setFlowToConfirmDelete],
  );

  const deleteFlow = useCallback(() => {
    const flowName = flowToConfirmDelete as AstarteFlow['name'];
    setIsDeletingFlow(true);
    astarte
      .deleteFlowInstance(flowName)
      .then(() => {
        setFlowToConfirmDelete(null);
        setIsDeletingFlow(false);
        instancesFetcher.refresh();
      })
      .catch((err) => {
        setIsDeletingFlow(false);
        deletionAlerts.showError(`Could not delete flow instance: ${err.message}`);
      });
  }, [
    flowToConfirmDelete,
    setFlowToConfirmDelete,
    setIsDeletingFlow,
    instancesFetcher.refresh,
    deletionAlerts.showError,
  ]);

  const handleModalCancel = useCallback(() => {
    setFlowToConfirmDelete(null);
  }, [setFlowToConfirmDelete]);

  return (
    <SingleCardPage title="Running Flows">
      <deletionAlerts.Alerts />
      <WaitForData
        data={instancesFetcher.value}
        status={instancesFetcher.status}
        fallback={
          <Container fluid className="text-center">
            <Spinner animation="border" role="status" />
          </Container>
        }
        errorFallback={
          <Empty title="Couldn't load flow instances" onRetry={instancesFetcher.refresh} />
        }
      >
        {(instances) => <InstancesTable instances={instances} onDelete={handleDeleteFlow} />}
      </WaitForData>
      <Button variant="primary" onClick={() => navigate('/pipelines')}>
        New flow
      </Button>
      {flowToConfirmDelete != null && (
        <ConfirmModal
          title="Warning"
          confirmLabel="Remove"
          confirmVariant="danger"
          onCancel={handleModalCancel}
          onConfirm={deleteFlow}
          isConfirming={isDeletingFlow}
        >
          <p>
            Delete flow <b>{flowToConfirmDelete}</b>?
          </p>
        </ConfirmModal>
      )}
    </SingleCardPage>
  );
};
