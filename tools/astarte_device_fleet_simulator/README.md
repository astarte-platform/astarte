# AstarteDeviceFleetSimulator

Load testing tool for Astarte. Simulates a configurable Astarte device fleet.
Configuration options are specified via the following environment variables:

- `DEVICE_FLEET_PAIRING_URL`: Pairing URL of your Astarte instance (e.g. https://api.astarte.example.com/pairing);
- `DEVICE_FLEET_REALM`: Name of your load testing realm (e.g. "loadtest"). Must be already installed;
- `DEVICE_FLEET_JWT`: The Astarte JWT employed to access Astarte APIs. The token can be generated with: `astartectl utils gen-jwt <service> -k <your-private-key>.pem`.
- `DEVICE_FLEET_IGNORE_SSL_ERRORS`: Ignore SSL errors during the test. Optional, defaults to `false`;
- `DEVICE_FLEET_SPAWN_INTERVAL_MILLISECONDS`: Time interval between consecutive spawns of Astarte devices (in milliseconds). Optional, defaults to `1000`;
- `DEVICE_FLEET_PUBLICATION_INTERVAL_MILLISECONDS`: Time interval between messages from a single Astarte devices (in milliseconds). Optional, defaults to `1000`;
- `DEVICE_FLEET_DEVICE_COUNT`: The number of Astarte device forming a test fleet. Optional, defaults to `10`;
- `DEVICE_FLEET_TEST_DURATION_SECONDS`: The length of the test (in seconds). Optional, defaults to `30`;
- `DEVICE_FLEET_PATH`: The path of the interface to which data are sent. Optional, defults to `"/streamTest/value"`. The interface is found in the `priv/interfaces` subdirectory;
- `DEVICE_FLEET_VALUE`: The value to send. Optional, defaults to `0.3`;
- `DEVICE_FLEET_QOS`: The QoS mode for messages sent from Astarte devices. Optional, defaults to `2`;
- `DEVICE_FLEET_ALLOW_MESSAGES_WHILE_SPAWNING`: Allow already connected Astarte devices to send messages while others are still connecting. Optional,defaults to `false`.
- `DEVICE_FLEET_INSTANCE_ID`: Fleet simulator instance ID. Must be unique for each instance when deploying multiple fleet simulator instances. Defaults to `astarte-fleet-simulator`.
- `DEVICE_FLEET_AVOID_REGISTRATION`: Avoid registration for already registered devices. The first time running with this option `true`, the devices will be (re)registered so that their credentials can be stored. Defaults to `false`.
- `DEVICE_FLEET_CREDENTIALS_SECRETS_LOCATION`: Location of the registered devices cache for `$DEVICE_FLEET_AVOID_REGISTRATION`. Defaults to `".credentials-secrets"`.

**Keep in mind that this tool is in WIP state.**

Run the load test with `mix run --no-halt`.

If you are running Astarte on `localhost` using `docker-compose`, you may need to set `DEVICE_FLEET_IGNORE_SSL_ERRORS` to true.
