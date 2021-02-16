# Sensor Channels example

This is a sample web page made in React that leverages Astarte Channels and shows live data of a
device sensors streamed in real time.

You can follow the walkthrough below if you wish to try it out: you will simulate a device that streams data from its sensors to Astarte and see this data flowing in real time.

## Prerequisites

For this example you should:

1. have an Astarte instance up and running with a realm you have access to
2. install the [example interfaces](../../standard-interfaces/) in the realm
3. register a device that will use those interfaces in the realm; be sure to note down its device ID
   and Credentials Secret
4. have [NodeJS](https://nodejs.org/) installed on your machine and serve this web page with
   ```sh
   npm install
   npm run start
   ```

If all went well, you should see a form where you can supply:

- the base URL of the Astarte instance
- the name of your realm
- a valid JWT access token for the realm that can be used to communicate with AppEngine and Channels

## Docker walkthrough

You can use Astarte's `stream-qt5-test` to emulate an Astarte device and generate a `datastream`:

```sh
docker run --net="host" -e "DEVICE_ID=<device_id>" -e "PAIRING_HOST=<pairing_host>" -e "REALM=<realm>" -e "AGENT_KEY=<agent_key>" -e "IGNORE_SSL_ERRORS=true" astarte/astarte-stream-qt5-test:1.0.0-beta.1
```

where `device_id` is the device you registered, `pairing_host` is the Astarte endpoint for the
Pairing APIs, `realm` is the name of your realm, `agent_key` is the valid JWT token of an Agent.

If all went well, `stream-qt5-test` should now be streaming data to Astarte.

Going back to the web page of this example, you can input the device ID to begin watching the
sensors data being streamed in real time from the device.

![Sensor Channels example, showing real time sensors data](../images/sensor-channels.png)
