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

import React from "react";
import { Link } from "react-router-dom";
import {
  Button,
  Col,
  Modal,
  OverlayTrigger,
  Row,
  Spinner,
  Table,
  Tooltip
} from "react-bootstrap";

import SingleCardPage from "./ui/SingleCardPage.js";

export default class FlowInstancesPage extends React.Component {
  constructor(props) {
    super(props);

    this.astarte = this.props.astarte;

    this.state = {
      phase: "loading",
      showModal: false
    };

    this.handleFlowResponse = this.handleFlowResponse.bind(this);
    this.handleFlowError = this.handleFlowError.bind(this);
    this.deleteInstance = this.deleteInstance.bind(this);
    this.handleInstanceResponse = this.handleInstanceResponse.bind(this);
    this.handleModalCancel = this.handleModalCancel.bind(this);
    this.deleteFlow = this.deleteFlow.bind(this);

    this.astarte
      .getFlowInstances()
      .then(this.handleFlowResponse)
      .catch(this.handleFlowError);
  }

  deleteInstance(instanceName) {
    this.setState({
      showModal: true,
      selectedFlow: instanceName,
    });
  }

  render() {
    let innerHTML;

    const {
      instances,
      phase,
      showModal,
      selectedFlow,
      deletingFlow
    } = this.state;

    switch (phase) {
      case "ok":
        innerHTML = (
          <InstancesTable
            instances={instances}
            onDelete={this.deleteInstance}
          />
        );
        break;

      case "err":
        innerHTML = <p>Couldn't load flow instances</p>;
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
        <Button
          variant="primary"
          onClick={() => { this.props.history.push("/pipelines") } }
        >
          New flow
        </Button>
        <ConfirmDeletionModal
          show={showModal}
          flowName={selectedFlow}
          isDeleting={deletingFlow}
          onCancel={this.handleModalCancel}
          onDelete={this.deleteFlow}
        />
      </SingleCardPage>
    );
  }

  handleModalCancel() {
    this.setState({
      showModal: false,
      selectedFlow: ""
    });
  }

  deleteFlow() {
    const flowName = this.state.selectedFlow;

    this.setState({
      deletingFlow: true
    });

    this.astarte
      .deleteFlowInstance(flowName)
      .then(() => {
        this.setState(oldState => {
          oldState.showModal = false;
          oldState.selectedFlow = "";
          oldState.deletingFlow = false;
          oldState.phase = "ok";
          oldState.instances = oldState.instances.filter(instance => instance.name != flowName);
          return oldState;
        });
      });
  }

  handleFlowResponse(response) {
    const instanceNames = response.data;

    if (instanceNames.length == 0) {
      this.setState({
        phase: "ok",
        instances: []
      });
    } else {
      this.setState({
        phase: "loading",
        instances: []
      });

      for (let name of instanceNames) {
        this.astarte.getFlowDetails(name).then(this.handleInstanceResponse);
      }
    }

    return null; // handle details async
  }

  handleInstanceResponse(response) {
    const instance = response.data;

    this.setState(oldState => {
      oldState.phase = "ok";
      oldState.instances.push(instance);
      return oldState;
    });
  }

  handleFlowError(err) {
    this.setState({
      phase: "err",
      error: err
    });
  }
}

function InstancesTable(props) {
  let instances = props.instances;

  if (instances.length == 0) {
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
        {instances.map((instance, index) => (
          <TableRow
            key={instance.name}
            instance={instance}
            onDelete={props.onDelete}
          />
        ))}
      </tbody>
    </Table>
  );
}

function TableRow(props) {
  const instance = props.instance;

  let colorClass;
  let tooltipText;

  switch (instance.status) {
    case "running":
      colorClass = "color-green";
      tooltipText = "Running";
      break;

    case "stopped":
      colorClass = "color-orange";
      tooltipText = "Stopped";
      break;

    default:
      // assume running
      colorClass = "color-green";
      tooltipText = "Running";
      break;
  }

  return (
    <tr>
      <td>
        <OverlayTrigger
          placement="right"
          delay={{ show: 150, hide: 400 }}
          style={{
            backgroundColor: "rgba(255, 100, 100, 0.85)",
            padding: "2px 10px",
            color: "white",
            borderRadius: 3
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
            backgroundColor: "rgba(255, 100, 100, 0.85)",
            padding: "2px 10px",
            color: "white",
            borderRadius: 3
          }}
          overlay={<Tooltip>Delete instance</Tooltip>}
        >
          <Button
            as="i"
            variant="danger"
            className="fas fa-times"
            onClick={() => props.onDelete(instance.name)}
          ></Button>
        </OverlayTrigger>
      </td>
    </tr>
  );
}

const CircleIcon = React.forwardRef((props, ref) => (
  <i ref={ref} {...props} className={`fas fa-circle ${props.className}`}>
    {props.children}
  </i>
));

function ConfirmDeletionModal(props) {
  const { show, flowName, isDeleting, onCancel, onDelete } = props;

  return (
    <div onKeyDown={(e) => { if (e.key == "Enter") onDelete() }}>
      <Modal
        size="sm"
        show={show}
        onHide={onCancel}
      >
        <Modal.Header closeButton>
          <Modal.Title>Warning</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <p>Delete flow <b>{flowName}</b>?</p>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={onCancel}>
            Cancel
          </Button>
          <Button variant="danger" onClick={onDelete}>
            <>
              {isDeleting ? (
                <Spinner
                  className="mr-1"
                  size="sm"
                  animation="border"
                  role="status"
                />
              ) : null}
              Remove
            </>
          </Button>
        </Modal.Footer>
      </Modal>
    </div>
  );
}
