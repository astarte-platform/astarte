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

import React, { useCallback, useEffect, useState } from "react";
import {
  Accordion,
  Button,
  Form,
  InputGroup,
  OverlayTrigger,
  Table,
  Tooltip,
  Spinner
} from "react-bootstrap";

import AstarteClient from "./AstarteClient.js";
import Device from "./astarte/Device.js";
import SingleCardPage from "./ui/SingleCardPage.js";
import CheckableDeviceTable from "./ui/CheckableDeviceTable.js";
import { Link } from "react-router-dom";

let alertId = 0;

export default ({ astarte, history }) => {
  const [phase, setPhase] = useState("loading");
  const [groupName, setGroupName] = useState("");
  const [deviceFilter, setDeviceFilter] = useState("");
  const [devices, setDevices] = useState([]);
  const [selectedDevices, setSelectedDevices] = useState(new Set());
  const [isCreatingGroup, setIsCreatingGroup] = useState(false);
  const [alerts, setAlerts] = useState(new Map());

  useEffect(() => {
    const handleDevicesRequest = (response) => {
      const deviceList = response.data.map((value) => Device.fromObject(value));
      setDevices(deviceList);
      setPhase("ok");
    };

    const handleDevicesError = (err) => {
      setPhase("err");
    };

    astarte
      .getDevices({ details: true })
      .then(handleDevicesRequest)
      .catch(handleDevicesError);

  }, [astarte]);

  const addAlert = useCallback(
    (message) => {
      alertId += 1;
      setAlerts((alerts) => {
        const newAlerts = new Map(alerts);
        newAlerts.set(alertId, message);
        return newAlerts;
      });
    },
    [setAlerts]
  );

  const closeAlert = useCallback(
    (alertId) => {
      setAlerts((alerts) => {
        const newAlerts = new Map(alerts);
        newAlerts.delete(alertId);
        return newAlerts;
      });
    },
    [setAlerts]
  );

  const createGroup = (e) => {
    e.preventDefault();

    setIsCreatingGroup(true);

    astarte
      .createGroup({
        groupName: groupName,
        deviceList: Array.from(selectedDevices)
      })
      .then(() => {
        history.push({ pathname: "/groups" });
      })
      .catch((err) => {
        addAlert(err.message);
        setIsCreatingGroup(false);
      });
  };

  const handleDeviceToggle = (e) => {
    const senderItem = e.target;
    const deviceId = senderItem.dataset.deviceId;

    setSelectedDevices((previousSelection) => {
      const newSelection = new Set(previousSelection);
      if (senderItem.checked) {
        newSelection.add(deviceId);
      } else {
        newSelection.delete(deviceId);
      }
      return newSelection;
    });
  };

  const selectedDeviceCount = selectedDevices.size;
  const isValidGroupName = groupName !== '' && !groupName.startsWith("@") && !groupName.startsWith("~");
  const isValidForm = isValidGroupName && selectedDeviceCount > 0;

  return (
    <NewGroupPageWrapper
      phase={phase}
      errorMessages={alerts}
      onAlertClose={closeAlert}
    >
      <Form onSubmit={createGroup}>
        <GroupNameFormGroup
          groupName={groupName}
          onGroupNameChange={setGroupName}
        />
        <div className="table-toolbar p-1">
          <span>
            { selectedDeviceCount > 0 ?
              `${selectedDeviceCount} ${selectedDeviceCount == 1 ? 'device' : 'devices'} selected.`
            :
              'Please select at least one device.'
            }
          </span>
          <div className="float-right">
            <FilterInputBox
              filter={deviceFilter}
              onFilterChange={setDeviceFilter}
            />
          </div>
        </div>
        <CheckableDeviceTable
          filter={deviceFilter}
          devices={devices}
          selectedDevices={selectedDevices}
          onToggleDevice={handleDeviceToggle}
        />
        <Form.Row className="flex-row-reverse pr-2">
          <Button
            variant="primary"
            type="submit"
            disabled={!isValidForm}
          >
            {isCreatingGroup && (
              <Spinner
                as="span"
                size="sm"
                animation="border"
                role="status"
                className={"mr-2"}
              />
            )}
            Create group
          </Button>
        </Form.Row>
      </Form>
    </NewGroupPageWrapper>
  );
}

const NewGroupPageWrapper = ({ phase, children, ...props }) => {
  let innerHtml;

  if (phase === "ok") {
    innerHtml = children;

  } else if (phase === "err") {
    innerHtml = (<p>Couldn't load the device list</p>);

  } else {
    innerHtml = (<Spinner animation="border" role="status" />);
  }

  return (
    <SingleCardPage title="Create a New Group" backLink="/groups" {...props}>
      {innerHtml}
    </SingleCardPage>
  );
}

const GroupNameFormGroup = ({ groupName, onGroupNameChange }) => {
  const isValidGroupName = !groupName.startsWith("@") && !groupName.startsWith("~");

  return (
    <Form.Group controlId="groupNameInput">
      <Form.Label>Group name</Form.Label>
      <Form.Control
        type="text"
        placeholder="Your group name"
        value={groupName}
        onChange={(e) => onGroupNameChange(e.target.value.trim())}
        autoComplete="off"
        required
        isValid={groupName !== '' && isValidGroupName}
        isInvalid={groupName !== '' && !isValidGroupName}
      />
      { !isValidGroupName &&
        <Form.Control.Feedback type="invalid">
          The group name cannot start with ~ or @.
        </Form.Control.Feedback>
      }
    </Form.Group>
  );
}

const FilterInputBox = ({ filter, onFilterChange }) => {
  return (
    <Form.Group>
      <Form.Label srOnly>Table filter</Form.Label>
      <InputGroup>
        <InputGroup.Prepend>
          <InputGroup.Text>
            <i className="fas fa-filter"></i>
          </InputGroup.Text>
        </InputGroup.Prepend>
        <Form.Control
          type="text"
          value={filter}
          onChange={(e) => onFilterChange(e.target.value)}
          placeholder="Device ID/alias"
        />
      </InputGroup>
    </Form.Group>
  );
}
