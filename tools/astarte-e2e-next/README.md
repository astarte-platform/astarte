<!--
Copyright 2026 SECO Mind Srl
SPDX-License-Identifier: CC0-1.0
-->

# Astarte E2E

Tools for running E2E tests against Astarte using `astarte-device-sdk-rust` to simulate the devices.

Two tools are provided:

- `astarte-e2e` is a test library designed to register a device and send data leveraging the device SDK, then verifying data delivery through Astarte APIs and triggers. It is intended for CI and local checks against a complete Astarte stack.

- `astarte-synthetic-monitoring` reuses the same checks as a long-running monitor. It periodically sends data from a pre-registered device and verifies the round trip, either continuously or for a fixed number of repetitions.

Both tools are intended to run from a container having access to the internal network of an Astarte deployment. The E2E suite runs as `cargo e2e` in the prebuilt test container. Synthetic monitoring runs as the compiled `astarte-synthetic-monitoring` binary in its runtime container.

## Local debugging (astarte-e2e)

The suggested approach for local development and debugging is to run a long-lived container with the source bind-mounted from the host and Cargo’s build cache stored in a persistent Docker volume. By doing so, each time the `cargo e2e` suite is launched only the recently changed code is recompiled; this avoids the need to rebuild the container for each modification.

It is suggested to run the container with all the needed environment variables precomputed and passed as input (e.g. as a file), in particular the following ones:

```
- E2E_JWT=$(astartectl utils gen-jwt all-realm-apis -k /path/to/realm/private/key.pem)

- E2E_ASTARTE_API_URL=$BASE_ASTARTE_URL
- E2E_PAIRING_URL=$BASE_ASTARTE_URL/pairing/
- E2E_APPENGINE_URL=$BASE_ASTARTE_URL/appengine/
- E2E_REALM_MANAGEMENT_URL=$BASE_ASTARTE_URL/realmmanagement/

- E2E_REALM=test

- E2E_AMQP_CONSUMER_HOST=rabbitmq

- E2E_IGNORE_SSL_ERRORS=true

## This to configure the log level for test crate and dependencies
- RUST_LOG=astarte_e2e=info,astarte_device_sdk=info
```

The long-running container can then be started (from root `astarte-e2e-next` directory) with

```
docker run -d \
  --env-file=/precomputed/env/file \
  --network astarte \
  --name astarte-e2e \
  -v "$PWD:/app" \
  -v astarte-cargo-cache:/tmp/cargo-target \
  -e CARGO_TARGET_DIR=/tmp/cargo-target \
  --rm astarte-e2e \
  sleep infinity`
```

The E2E tests can now be launched via

`docker exec astarte-e2e cargo e2e -- --nocapture` (use nocapture to show logs)
