# Sensor Sampling Rate example

This is a sample web page made in React that you can use to show existing sensors of a device and
configure their activity and sampling rates.

You can follow the walkthrough below if you wish to try it out: you will first simulate a device
that stream data from its sensors to Astarte, then use this web page to lookup and configure those sensors.

## Prerequisites

For this example you should:

1. have an Astarte instance up and running with a realm you have access to
2. install the [example interfaces](../../standard-interfaces/) in the realm
3. register a device that will use those interfaces in the realm; note down its device ID and
   Credentials Secret
4. have [NodeJS](https://nodejs.org/) installed on your machine and serve this web page with
   ```sh
   npm install
   npm run start
   ```

If all went well, you should see a form where you can supply:

- the base URL of the Astarte instance
- the name of your realm
- a valid JWT access token for the realm that can be used to communicate with AppEngine

## Elixir walkthrough

A device SDK, such as the
[Elixir SDK](https://github.com/astarte-platform/astarte-device-sdk-elixir), can be used to simulate
the device and stream data to Astarte.

You can download a local copy of the Elixir SDK on your machine, install
[Elixir](https://elixir-lang.org/), and launch an interactive session with the SDK with:

```sh
iex -S mix
```

Let's first load some useful variables in the interactive session; replace right members of the
assignments as needed:

```elixir
device_id = "DEVICE_ID"
credentials_secret = "DEVICE_CREDENTIALS_SECRET"
realm = "REALM_NAME"
pairing_url = "PAIRING_URL"
interfaces_folder = "/path/to/interfaces"
```

Note that `interfaces_folder` is the folder on your machine where you have the JSON definitions for
the [example interfaces](../../standard-interfaces/).

We can pass these options to the SDK to create a virtual Device and have it connected to the realm:

```elixir
opts = [pairing_url: pairing_url, realm: realm, device_id: device_id, credentials_secret: credentials_secret, interface_provider: interfaces_folder, ignore_ssl_errors: true]
{:ok, pid} = Astarte.Device.start_link(opts)
```

The virtual Device should now be connected and the SDK has advertised the device's introspection, i.e. which interfaces the device supports to exchange data.

We can now use the device to stream data via the `Values` interface. Let's say the device has two sensors and it measured a temperature of 19°C and a relative humidity of 45%:

```elixir
Astarte.Device.send_datastream(pid, "org.astarte-platform.genericsensors.Values", "/temperature1/value", 19)
Astarte.Device.send_datastream(pid, "org.astarte-platform.genericsensors.Values", "/humidity1/value", 45)
```

Going back to the web page of this example, you can input the device ID to search for the sensors we just simulated.

You now have a mean to configure each sensor and to review its current setup:

![Sensor Sampling Rate example, configuring a device's sensors](../images/sensor-samplingrate.png)
