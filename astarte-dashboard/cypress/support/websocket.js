import { WebSocket, Server } from 'mock-socket';

const CHANNEL_EVENTS = {
  close: 'phx_close',
  error: 'phx_error',
  join: 'phx_join',
  reply: 'phx_reply',
  leave: 'phx_leave',
};

const CHANNEL_CUSTOM_EVENTS = {
  watch: 'watch',
  watchAdded: 'watch_added',
  newEvent: 'new_event',
};

const decodeMessage = (messageString) => {
  const [joinRef, ref, topic, event, payload] = JSON.parse(messageString);
  return { joinRef, ref, topic, event, payload };
};

const encodeMessage = (message) => {
  const { joinRef, ref, topic, event, payload } = message;
  return JSON.stringify([joinRef, ref, topic, event, payload]);
};

const computeMessageAck = (message) => {
  const { joinRef, ref, topic } = message;
  const messageAck = {
    joinRef,
    ref,
    topic,
    event: CHANNEL_EVENTS.reply,
    payload: { response: {}, status: 'ok' },
  };
  return messageAck;
};

const computeMessageReply = (message) => {
  const { topic, event, payload } = message;
  switch (event) {
    case CHANNEL_CUSTOM_EVENTS.watch:
      return {
        joinRef: null,
        ref: null,
        topic,
        event: CHANNEL_CUSTOM_EVENTS.watchAdded,
        payload,
      };
    default:
      return null;
  }
};

const generateDeviceMessage = (context, { deviceId, event }) => {
  if (!context.currentTopic || !deviceId || !event) {
    return null;
  }
  const message = {
    joinRef: null,
    ref: null,
    topic: context.currentTopic,
    event: CHANNEL_CUSTOM_EVENTS.newEvent,
    payload: {
      device_id: deviceId,
      event,
      timestamp: new Date().toISOString(),
    },
  };
  return message;
};

const sendMessage = (context, message) => {
  if (!message || !context.mockedSocket) {
    return;
  }
  context.mockedSocket.send(encodeMessage(message));
};

const injectMock = (context, url) => {
  if (!url) {
    return;
  }
  context.WebSocket = WebSocket;
  if (context.mockedServer) {
    context.mockedServer.stop();
    context.mockedServer = null;
    context.mockedSocket = null;
    context.currentTopic = null;
  }
  context.mockedServer = new Server(url);
  context.mockedServer.on('connection', (socket) => {
    context.mockedSocket = socket;
    context.mockedSocket.on('message', (messageString) => {
      const message = decodeMessage(messageString);
      context.currentTopic = message.topic;
      const messageAck = computeMessageAck(message);
      const messageReply = computeMessageReply(message);
      sendMessage(context, messageAck);
      sendMessage(context, messageReply);
    });
  });
};

const sendDeviceConnected = (context, { deviceId, deviceIpAddress }) => {
  const event = { device_ip_address: deviceIpAddress || '1.1.1.1', type: 'device_connected' };
  const message = generateDeviceMessage(context, { deviceId, event });
  sendMessage(context, message);
};

const sendDeviceDisconnected = (context, { deviceId }) => {
  const event = { type: 'device_disconnected' };
  const message = generateDeviceMessage(context, { deviceId, event });
  sendMessage(context, message);
};

const sendDeviceEvent = (context, { deviceId, event }) => {
  const message = generateDeviceMessage(context, { deviceId, event });
  sendMessage(context, message);
};

export default {
  injectMock,
  sendDeviceConnected,
  sendDeviceDisconnected,
  sendDeviceEvent,
};
