# Sensors Viewer example

This is a sample web page made in vanilla JavaScript that you can use to show available sensors of a
device and their data.

You can follow the walkthrough below if you wish to try it out: you will first simulate a device
that streams data from its sensors to Astarte, then use this web page to retrieve an overview of the
device sensors from Astarte.

## Prerequisites

For this example you should:

1. have an Astarte instance up and running with a realm you have access to
2. install the [example interfaces](../../standard-interfaces/) in the realm
3. register a device that will use those interfaces in the realm; be sure to note down its device ID
   and Credentials Secret
4. modify the `configuration` variable in `index.html` and specify: the `endpoint` of the Astarte
   instance, the `realm` you chose, a valid JWT `token` that can be used to communicate with
   AppEngine, the `device` ID your registered.

## Docker walkthrough

You can use Astarte's `stream-qt5-test` to emulate an Astarte device and generate a `datastream`:

```sh
docker run --net="host" -e "DEVICE_ID=<device_id>" -e "PAIRING_HOST=<pairing_host>" -e "REALM=<realm>" -e "AGENT_KEY=<agent_key>" -e "IGNORE_SSL_ERRORS=true" astarte/astarte-stream-qt5-test:0.11.4
```

where `device_id` is the device you registered, `pairing_host` is the Astarte endpoint for the
Pairing APIs, `realm` is the name of your realm, `agent_key` is the valid JWT token of an Agent.

If all went well, `stream-qt5-test` should now be streaming data to Astarte.

Going back to the web page of this example, you can input the device ID to request an overview of
the device sensors and their data.

![Sensors Viewer example, requesting the overview of a device sensors and their data](../images/javascript-sensors-viewer-stream-test.png)
