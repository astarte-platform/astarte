# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.4.0-rc.3] - 2026-07-31

## [1.4.0-rc.2] - 2026-07-14

## [1.4.0-rc.1] - 2026-07-13

## [1.4.0-rc.0] - 2026-04-07

### Changed

- Update VerneMQ to 2.0.1
- Use mississippi as AMQP publisher

## [1.3.2] - 2026-07-14

## [1.3.1] - 2026-07-10

## [1.3.0] - 2026-05-05

## [1.3.0-rc.2] - 2026-01-23

## [1.3.0-rc.1] - 2026-01-23

## [1.3.0-rc.0] - 2025-11-21

### Added

- Add the option to enable keepalive for scylladb connections, using the environment variable
  `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__ENABLE_KEEPALIVE`. Defaults to `true`
- Devices can now declare support for optional Astarte MQTT v1 features to Astarte via capabilities

## [1.2.2] - 2026-04-27

## [1.2.2-rc.0] 2026-04-08

### Fixed

- Avoid race conditions preventing correct processing of device deletion requests

## [1.2.1] 2026-03-06

## [1.2.1-rc.1] 2026-02-13

### Added

- Add the option to enable keepalive for scylladb connections, using the environment variable
  `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__ENABLE_KEEPALIVE`. Defaults to `true`

## [1.2.1-rc.0] 2025-08-22

### Changed

- RPC now uses erlang clustering instead of `astarte_rpc`

## [1.2.1-alpha.0] - 2025-04-10

### Added

- Allow to set the Erlang cookie via the `RELEASE_COOKIE`
  env var. Default to `vmq` for backwards compatibility.

## [1.2.0] - 2024-07-01

## [1.2.0-rc.0] - 2024-05-29

### Added

- The plugin now accesses the Astarte database. The following
  env variables have been added:
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__NODES`
    (defaults to `localhost:9042`)
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__USERNAME`
    (defaults to `cassandra`)
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__PASSWORD`
    (defaults to `cassandra`)
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__POOL_SIZE`
    (defaults to 10)
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__SSL_ENABLED`
    (defaults to `false`)
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__SSL_DISABLE_SNI`
    (defaults to `true`)
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__SSL_CUSTOM_SNI`
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__CASSANDRA__SSL_CA_FILE`
- Added support for device deletion. During deletion, a device is
  disconnected and not allowed to reconnect until deletion ends.
  Inflight messages are discarded. After deletion, a device must be
  registered again in order to connect to Astarte.
- Added support for multiple Astarte instances sharing the same database,
  the following env variable has been added:
  - `DOCKER_VERNEMQ_ASTARTE_VMQ_PLUGIN__ASTARTE_INSTANCE_ID`
    (defaults to ``)
- Added support for `capabilities` message topic at `/<realm name>/<device name>/capabilities`

### Changed

- Update Elixir to 1.15.7.
- Update Erlang/OTP to 26.1.
- Update VerneMQ to master (1cc57fa) to support OTP 26.

## [1.1.1] - 2023-10-03

## [1.1.0] - 2023-06-20

## [1.1.0-rc.0] - 2023-06-09

### Changed

- Use the `internal` event type for device heartbeat.
- Update Elixir to 1.14.5 and Erlang/OTP to 25.3.2.

## [1.1.0-alpha.0] - 2022-11-24

### Fixed

- Correctly serialize disconnection/reconnection events if VerneMQ hooks are called in
  the wrong order. Fix https://github.com/astarte-platform/astarte/issues/668.

## [1.0.6] - 2024-04-18

## [1.0.5] - 2023-09-25

## [1.0.4] - 2022-09-26

### Fixed

- Do not let VerneMQ container start unless the CA cert is retrieved from CFSSL.
- Prevent the connection from timing out when the client takes more than 5 seconds to perform the
  SSL handshake

### Security

- Rebuild official docker image (updates OTP to 23.3.4.17), in order to fix CVE-2022-37026.

## [1.0.3] - 2022-04-07

## [1.0.2] - 2022-03-30

## [1.0.1] - 2021-12-16

### Fixed

- Do not override VerneMQ config `max_message_rate` value.

## [1.0.0] - 2021-06-30

### Changed

- Log plugin version when the application is starting.

## [1.0.0-rc.0] - 2021-05-05

## [1.0.0-beta.2] - 2021-03-24

### Changed

- Update Elixir to 1.11.4 and Erlang/OTP to 23.2
- Do not authorize non-devices blindly in `auth_on_publish` and `auth_on_subscribe`.

## [1.0.0-beta.1] - 2021-02-16

### Changed

- Default data_queue_count to 128.

## [1.0.0-alpha.1] - 2020-06-19

### Added

- Send a periodic heartbeat for every connected device.
- Support SSL for RabbitMQ connections.
- Default max certificate chain length to 10.
- Reply with local and remote matches when a publish is requested.
- Allow configuring `max_offline_messages` and `persistent_client_expiration` with Docker env
  variables

## [0.11.4] - 2021-01-26

### Fixed

- Fix a bug where the plugin would remain unfunctional after suddenly disconnecting from RabbitMQ.

## [0.11.3] - 2020-09-24

### Fixed

- Fix bug that prevented property unset

## [0.11.2] - 2020-08-14

### Added

- Update Elixir to 1.8.2

## [0.11.1] - 2020-05-18

### Added

- Enhance docker build process

## [0.11.0] - 2020-04-13

## [0.11.0-rc.1] - 2020-03-26

## [0.11.0-rc.0] - 2020-02-26

## [0.11.0-beta.2] - 2020-01-24

## [0.11.0-beta.1] - 2019-12-26

### Added

- Add support to multiple queues with consistent hashing

## [0.10.2] - 2019-12-09

## [0.10.1] - 2019-10-02

## [0.10.0] - 2019-04-16

## [0.10.0-rc.1] - 2019-04-10

### Fixed

- Re-enable SSL listener, which broke Docker Compose.

## [0.10.0-rc.0] - 2019-04-03

## [0.10.0-beta.3] - 2018-12-19

## [0.10.0-beta.2] - 2018-10-19

## [0.10.0-beta.1] - 2018-08-27

### Added

- First Astarte release.
