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

import React, { useEffect, useState } from 'react';
import { Badge, Card } from 'react-bootstrap';

import AstarteClient, {
  AstarteDeviceEvent,
  AstarteDeviceConnectedEvent,
  AstarteDeviceDisconnectedEvent,
  AstarteDeviceErrorEvent,
  AstarteDeviceIncomingDataEvent,
  AstarteDeviceUnsetPropertyEvent,
} from 'astarte-client';
import FullHeightCard from '../components/FullHeightCard';

interface SystemEvent {
  level: 'error' | 'info';
  message: string;
  timestamp: number;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function isSystemEvent(arg: any): arg is SystemEvent {
  return arg && arg.level && (arg.level === 'error' || arg.level === 'info');
}

type RenderableEvent = SystemEvent | AstarteDeviceEvent;

interface WatchDeviceEventsParams {
  astarte: AstarteClient;
  deviceId: string;
  onEventReceived: (event: AstarteDeviceEvent) => void;
  onErrorMessage: (msg: string) => void;
  onInfoMessage: (msg: string) => void;
}

function watchDeviceEvents({
  astarte,
  deviceId,
  onEventReceived,
  onErrorMessage,
  onInfoMessage,
}: WatchDeviceEventsParams): void {
  const salt = Math.floor(Math.random() * 10000);
  const roomName = `dashboard_${deviceId}_${salt}`;

  astarte
    .joinRoom(roomName)
    .then(() => {
      onInfoMessage(`Joined room for device ${deviceId}`);

      astarte.listenForEvents(roomName, (event) => onEventReceived(event));

      const connectionTriggerPayload = {
        name: `connectiontrigger-${deviceId}`,
        device_id: deviceId,
        simple_trigger: {
          type: 'device_trigger',
          on: 'device_connected',
          device_id: deviceId,
        },
      };

      const disconnectionTriggerPayload = {
        name: `disconnectiontrigger-${deviceId}`,
        device_id: deviceId,
        simple_trigger: {
          type: 'device_trigger',
          on: 'device_disconnected',
          device_id: deviceId,
        },
      };

      const errorTriggerPayload = {
        name: `errortrigger-${deviceId}`,
        device_id: deviceId,
        simple_trigger: {
          type: 'device_trigger',
          on: 'device_error',
          device_id: deviceId,
        },
      };

      const dataTriggerPayload = {
        name: `datatrigger-${deviceId}`,
        device_id: deviceId,
        simple_trigger: {
          type: 'data_trigger',
          on: 'incoming_data',
          interface_name: '*',
          value_match_operator: '*',
          match_path: '/*',
        },
      };

      astarte
        .registerVolatileTrigger(roomName, connectionTriggerPayload)
        .then(() => {
          onInfoMessage('Watching for device connection events');
        })
        .catch(() => {
          onErrorMessage("Coulnd't watch for device connection events");
        });

      astarte
        .registerVolatileTrigger(roomName, disconnectionTriggerPayload)
        .then(() => {
          onInfoMessage('Watching for device disconnection events');
        })
        .catch(() => {
          onErrorMessage("Coulnd't watch for device disconnection events");
        });

      astarte
        .registerVolatileTrigger(roomName, errorTriggerPayload)
        .then(() => {
          onInfoMessage('Watching for device error events');
        })
        .catch(() => {
          onErrorMessage("Coulnd't watch for device error events");
        });

      astarte
        .registerVolatileTrigger(roomName, dataTriggerPayload)
        .then(() => {
          onInfoMessage('Watching for device data events');
        })
        .catch(() => {
          onErrorMessage("Coulnd't watch for device data events");
        });
    })
    .catch(() => {
      onErrorMessage(`Couldn't join device ${deviceId} room`);
    });
}

interface TimestampProps {
  children: Date;
}

const Timestamp = ({ children }: TimestampProps): React.ReactElement => {
  const formattedTimestamp = children.toISOString().substring(11, 23);

  return <small className="text-secondary text-monospace mr-2">{`[${formattedTimestamp}]`}</small>;
};

const deviceErrorNameToString = (errorName: string): string => {
  switch (errorName) {
    case 'write_on_server_owned_interface':
      return 'Write on a server owned interface';

    case 'invalid_interface':
      return 'Invalid interface';

    case 'invalid_path':
      return 'Invalid path';

    case 'mapping_not_found':
      return 'Mapping not found';

    case 'interface_loading_failed':
      return 'Interface loading failed';

    case 'ambiguous_path':
      return 'Ambiguous path';

    case 'undecodable_bson_payload':
      return 'Undecodable BSON payload';

    case 'unexpected_value_type':
      return 'Unexpected value type';

    case 'value_size_exceeded':
      return 'Value size exceeded';

    case 'unexpected_object_key':
      return 'Unexpected object key';

    case 'invalid_introspection':
      return 'Invalid introspection';

    case 'unexpected_control_message':
      return 'Unexpected control message';

    case 'device_session_not_found':
      return 'Device session not found';

    case 'resend_interface_properties_failed':
      return 'Resend interface properties failed';

    case 'empty_cache_error':
      return 'Empty cache error';

    default:
      return '';
  }
};

const astarteDeviceEventBody = (event: AstarteDeviceEvent) => {
  if (event instanceof AstarteDeviceConnectedEvent) {
    return (
      <>
        <Badge variant="success" className="mr-2">
          device connected
        </Badge>
        <span>IP : {event.ip}</span>
      </>
    );
  }
  if (event instanceof AstarteDeviceDisconnectedEvent) {
    return (
      <>
        <Badge variant="warning" className="mr-2">
          device disconnected
        </Badge>
        <span>Device disconnected</span>
      </>
    );
  }
  if (event instanceof AstarteDeviceIncomingDataEvent) {
    return (
      <>
        <Badge variant="info" className="mr-2">
          incoming data
        </Badge>
        <span className="mr-2">{event.interfaceName}</span>
        <span className="mr-2">{event.path}</span>
        <span className="mr-2 text-monospace">{event.value}</span>
      </>
    );
  }
  if (event instanceof AstarteDeviceUnsetPropertyEvent) {
    return (
      <>
        <Badge variant="info" className="mr-2">
          unset property
        </Badge>
        <span className="mr-2">{event.interfaceName}</span>
        <span>{event.path}</span>
      </>
    );
  }
  if (event instanceof AstarteDeviceErrorEvent) {
    return (
      <>
        <Badge variant="danger" className="mr-2">
          device error
        </Badge>
        <span>{deviceErrorNameToString(event.errorName)}</span>
      </>
    );
  }
  return <></>;
};

interface AstarteDeviceEventDelegateProps {
  event: AstarteDeviceEvent;
}

const AstarteDeviceEventDelegate = ({ event }: AstarteDeviceEventDelegateProps) => (
  <li className="event-device px-2">
    <Timestamp>{new Date(event.timestamp)}</Timestamp>
    {astarteDeviceEventBody(event)}
  </li>
);

interface SystemEventDelegateProps {
  event: SystemEvent;
}

const SystemEventDelegate = ({ event }: SystemEventDelegateProps) => {
  switch (event.level) {
    case 'error':
      return (
        <li className="px-2">
          <Timestamp>{new Date(event.timestamp)}</Timestamp>
          <Badge variant="secondary" className="mr-2">
            channel
          </Badge>
          <span className="text-danger">{event.message}</span>
        </li>
      );

    case 'info':
    default:
      return (
        <li className="px-2">
          <Timestamp>{new Date(event.timestamp)}</Timestamp>
          <Badge variant="secondary" className="mr-2">
            channel
          </Badge>
          <span className="text-secondary">{event.message}</span>
        </li>
      );
  }
};

interface EventDelegateProps {
  event: RenderableEvent;
}

const EventDelegate = ({ event }: EventDelegateProps) => {
  if (isSystemEvent(event)) {
    return <SystemEventDelegate event={event} />;
  }

  return <AstarteDeviceEventDelegate event={event} />;
};

interface DeviceLiveEventsViewProps {
  astarte: AstarteClient;
  deviceId: string;
}

const DeviceLiveEventsView = ({
  astarte,
  deviceId,
}: DeviceLiveEventsViewProps): React.ReactElement => {
  const [deviceEvents, setDeviceEvents] = useState<RenderableEvent[]>([]);

  const registerEvent = (event: RenderableEvent) => {
    setDeviceEvents((oldEvents: RenderableEvent[]) => [...oldEvents, event]);
  };

  const sendErrorMessage = (errorMessage: string) =>
    registerEvent({
      message: errorMessage,
      level: 'error',
      timestamp: Date.now(),
    });

  const sendInfoMessage = (infoMessage: string) =>
    registerEvent({
      message: infoMessage,
      level: 'info',
      timestamp: Date.now(),
    });

  useEffect(() => {
    const handleSocketError = () => sendErrorMessage('Astarte channels communication error');
    const handleSocketClose = () => sendErrorMessage('Lost connection with the Astarte channel');

    astarte.addListener('socketError', handleSocketError);
    astarte.addListener('socketClose', handleSocketClose);

    watchDeviceEvents({
      astarte,
      deviceId,
      onEventReceived: registerEvent,
      onErrorMessage: sendErrorMessage,
      onInfoMessage: sendInfoMessage,
    });

    return () => {
      astarte.removeListener('socketError', handleSocketError);
      astarte.removeListener('socketClose', handleSocketClose);
      astarte.joinedRooms.forEach((room: string) => {
        astarte.leaveRoom(room);
      });
    };
  }, [deviceId, astarte]);

  return (
    <div className="device-event-container p-3">
      <ul className="list-unstyled">
        {deviceEvents.map((event, index: number) => (
          <EventDelegate key={index} event={event} />
        ))}
      </ul>
    </div>
  );
};

interface DeviceLiveEventsCardProps {
  astarte: AstarteClient;
  deviceId: string;
}

const DeviceLiveEventsCard = ({
  astarte,
  deviceId,
}: DeviceLiveEventsCardProps): React.ReactElement => (
  <FullHeightCard xs={12} className="mb-4">
    <Card.Header as="h5">Device Live Events</Card.Header>
    <Card.Body className="d-flex flex-column">
      <DeviceLiveEventsView astarte={astarte} deviceId={deviceId} />
    </Card.Body>
  </FullHeightCard>
);

export default DeviceLiveEventsCard;
