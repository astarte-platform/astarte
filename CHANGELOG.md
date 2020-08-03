# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.0.0-beta.1] - Unreleased
### Fixed
- [astarte_appengine_api] Fix regression that made it impossible to use Astarte Channels.
- [astarte_appengine_api] Fix bug that prevented data publishing in object aggregated interfaces.
- [astarte_appengine_api] Fix regression that prevented properties to be set before the first
  connection of a device.
- [astarte_realm_management] Fix a bug that prevented AMQP triggers to be correctly installed.

### Added
- [astarte_housekeeping] Allow deleting a realm. The feature can be enabled with an environment
  variable (defaults to disabled).

### Changed
- [astarte_housekeeping_api] Remove format check on Cassandra datacenter name when a realm is
  created, the datacenter is just verified against the one present in the database.
- [housekeeping] Increase the delay between connection attempts to 1000 ms, for an overall number
  of 60 attempts.
- [data_updater_plant] Default the total queue count to 128, de facto exploiting multiqueue support.
- [data_updater_plant] Default the queue range end to 127.

## [1.0.0-alpha.1] - 2020-06-19
### Fixed
- Make sure devices are eventually marked as disconnected even if they disconnect while VerneMQ is
  temporarily down (see [#305](https://github.com/astarte-platform/astarte/issues/305)).

### Changed
- [appengine_api] Always return an object when GETting on object aggregated interfaces.
- Replace Conform and Distillery with Elixir native releases.
- Remove the `ASTARTE_` prefix from all env variables.
- [realm_management_api] Triggers http actions are now validated.
- [realm_management_api] It is now possible to omit the `device_id` in a `device_trigger`. This is
  equivalent to passing `*` as `device_id`. The old behaviour is still supported.

### Added
- [appengine_api] Add metadata to device
- [trigger_engine] Allow configuring preferred http method (such as `PUT` or `GET`)
  (see [#128](https://github.com/astarte-platform/astarte/issues/128)).
- [trigger_egnine] Add optional support to custom http headers, such as
  `Authorization: Bearer ...` (see [#129](https://github.com/astarte-platform/astarte/issues/129)).
- [data_updater_plant] Handle device hearbeat sent by VerneMQ plugin.
- [data_updater_plant] Deactivate Data Updaters when they don't receive messages for some time,
  freeing up resources.
- [appengine_api] Support SSL connections to RabbitMQ.
- [data_updater_plant] Support SSL connections to RabbitMQ.
- [trigger_engine] Support SSL connections to RabbitMQ.
- Default max certificate chain length to 10.
- AMQP trigger actions (publish to custom exchanges) as an alternative to http triggers actions.
- Ensure data pushed towards the device is correctly delivered when using QoS > 0.
- [realm_management_api] Allow installing device-specific and group-specific triggers. To do so,
  pass the `device_id` or `group_name` key inside the `simple_trigger`.
- [data_updater_plant] Add support for device-specific and group-specific triggers.
- Add support for device error triggers.

### Removed
- [appengine_api] Remove deprecated not versioned socket route.

## [0.11.2] - Unreleased
### Added
- [trigger_engine] Add `ignore_ssl_errors` key in trigger actions, allowing to ignore SSL actions
  when delivering an HTTP trigger action.

### Changed
- [appengine_api] Remove `topic` from channel metrics.

## [0.11.1] - 2020-05-18
### Added
- [data_updater_plant] Add `DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_TOTAL_COUNT` environment variable,
  this must be equal to the total number of queues in the Astarte instance.
- [trigger_engine] Add `TRIGGER_ENGINE_AMQP_PREFETCH_COUNT` environment variable to set the
  prefetech count of AMQPEventsConsumer, avoiding excessive memory usage.

### Fixed
- Wait for schema_version agreement before applying any schema change (such as creating tables or a
  new realm). (see [#312](https://github.com/astarte-platform/astarte/issues/312).
- [appengine_api] Fix the metric counting discarded channel events, it was not correctly increased.
- [data_update_plant] Validate UTF8 strings coming from the broker (i.e. interface and path) to
  avoid passing invalid strings to the database.
- [data_updater_plant] Fix a bug that was sometimes stalling a data updater queue process (see
  [#375](https://github.com/astarte-platform/astarte/issues/375).

## [0.11.0] - 2020-04-13
### Fixed
- [appengine_api] Handle server owned datetime values correctly
- [housekeeping] Fix a bug preventing the public key of newly created realms to be correctly
  inserted to the realm (see #294).
- [data_updater_plant] Fix a bug that was preventing volatile triggers (specifically, the ones
  targeting the `*` interface) to be loaded immediately.

## [0.11.0-rc.1] - 2020-03-26
### Fixed
- [data_updater_plant] Discard unexpected object aggregated values on individual interfaces.
- [trigger_engine] 500 was not included in the range of HTTP server errors, causing a crash.

## [0.11.0-rc.0] - 2020-02-26
### Added
- [pairing_api] Add health endpoint.
- [realm_management_api] Add health endpoint.
- [housekeeping] Add Prometheus instrumenters and exporters.
- [trigger_engine] Add health endpoint.
- [housekeeping] Add health endpoint.
- [realm_management] Add health endpoint.
- [pairing] Add health endpoint.
- [data_updater_plant] Add health endpoint.
- [data_updater_plant] Export specific metrics with telemetry.
- [trigger_engine] Export specific metrics with telemetry.
- [appengine_api] Export specific metrics with telemetry.

### Changed
- [realm_management] Correctly handle parametric endpoints regardless of the ordering, so that overlapping endpoints are always refused.
- [all] Make Elixir logger handle OTP requests: print stack traces only when needed.
- [appengine_api] Handle aggregated server owned interfaces.
- [appengine-api] Handle TTL for server owned interfaces.

## [0.11.0-beta.2] - 2020-01-24
### Added
- [pairing] Add Prometheus instrumenters and exporters.
- [realm_management] Add Prometheus instrumenters and exporters.
- [housekeeping_api] Add pretty_log.
- [trigger_engine] Add pretty_log.
- [pairing] Add pretty_log.
- [pairing_api] Add Prometheus instrumenters and exporters
- [realm_management_api] Add Prometheus instrumenters and exporters
- [housekeeping_api] Add Prometheus instrumenters and exporters
- Add standard interfaces for generic sensors.
- [trigger_engine] Add Prometheus instrumenters and exporters
- [pairing] Expose registration count and get_credentials count metrics.

### Changed
- [realm_management] Handle hyphens in `interface_name`. ([#96](https://github.com/astarte-platform/astarte/issues/96))
- [realm_management] Restrict the use of `*` as `interface_name` only to `incoming_data` data
  triggers.

### Fixed
- [data_updater_plant] Load `incoming_data` triggers targeting `any_interface`.
  ([#139](https://github.com/astarte-platform/astarte/issues/139))
- [housekeeping] Remove extra column in realm migration, preventing the correct upgrade to 0.11.
- [appengine_api] Fix crash that was happening when Channels received an event with an empty BSON as
  value (e.g. an IncomingDataEvent generated by an unset property).

## [0.11.0-beta.1] - 2019-12-26
### Added
- Add astarte_import tool, which allows users to import devices and data using XML files.
- [appegnine_api] Add new `/v1/socket` route for Astarte Channels. The `/socket` route is **deprecated** and will be
  removed in a future release.
- [appengine_api] Add groups support, allowing to group devices and access them inside a group hierarchy.
- [appengine_api] Add Prometheus metrics.
- [appengine_api] Show interface stats (exchanged messages and bytes) in device introspection.
- [appengine_api] Add previous_interfaces field to device details.
- [appengine_api] Allow installing group triggers in Astarte Channels.
- [data_updater_plant] Add support to multiple queues with consistent hashing
- [data_updater_plant] Save exchanged bytes and messages for all interfaces.
- [housekeeping] Add groups related columns and tables (schema has been changed).
- [housekeeping] Add interface stats related columns (schema has been changed).
- [housekeeping] Add database retention ttl and policy related columns (schema has been changed).
- Allow specifying initial introspection when registering a device.
- [realm_management] Trigger validation, checks that the interface is existing and performs validation on object aggregation triggers.

### Changed
- Use separate docker images with docker-compose
- Use Scylla instead of Cassandra with docker-compose
- Authorization regular expressions must not have delimiters: they are implicit.
- [appengine_api] Change logs format to logfmt.
- [data_updater_plant] Changed logs format to logfmt.
- [realm_management] Changed logs format to logfmt.
- [realm_management_api] Changed logs format to logfmt.
- [housekeeping] Change database driver, start using Xandra.
- [housekeeping_api] Move health check API from /v1/health to /health to be consistent with all Astarte components.

## [0.10.2] - 2019-12-09
### Added
- [appengine_api] Add timestamp field to channel events.
- Add device unregister API, allowing to reset the registration of a device.
- [trigger_engine] Trigger timestamp is now extracted from SimpleEvent and not generated.
  This means that all triggers generated from the same event will have the same timestamp.

### Fixed
- [appengine_api] Fix invalid dates handling, they should not cause an internal server error.
- [appengine_api] Gracefully handle existing aliases instead of returning an internal server error.
- [appengine_api] Fix querying object aggregated interface with explicit timestamp, use value_timestamp to avoid
an internal server error.
- [appengine_api] Device details now show false in the connected field for never connected devices (null was
  returned before)
- [appengine_api] Handle out-of-band RPC errors gracefully instead of crashing.
- [data_updater_plant] Do not accept invalid paths that have consecutive slashes.
- [data_updater_plant] Do not accept invalid paths in object aggregated interfaces.
- [data_updater_plant] Do not delete all congruent triggers when deleting a volatile trigger.
- [data_updater_plant] Load volatile device triggers as soon as they're installed.
- [realm_management_api] Handle trigger not found reply from RPC, return 404 instead of 500.

### Changed
- Use the timestamp sent by VerneMQ (or explicit timestamp if available) to populate SimpleEvent timestamp.
- [data_updater_plant] Update suggested RabbitMQ version to 3.7.15, older versions can be still used.

## [0.10.1] - 2019-10-02
### Added
- Support both SimpleStrategy and NetworkTopologyStrategy replications when creating a realm.
- Add sanity checks on the replication factor during realm creation.

### Fixed
- Auth was refusing any POST method, a workaround has been added, however this will not work with regex.
- Fix reversed order when sending binaryblobarray and datetimearray.
- [data_updater_plant] Fix a bug that was causing a crash-loop in some corner cases when a message was sent on an outdated interface.
- [data_updater_plant] Send consumer properties correctly when handling `emptyCache` control message.
- Use updated interface validation: object aggregated properties interfaces are not valid.
- Use updated interface validation: server owned object aggregated interfaces are not yet supported, hence not valid.
- [realm_management_api] Trying to create a trigger with an already taken name now fails gracefully with an error instead of crashing.
- [trigger_engine] Fix datetime type handling, now it is properly serialized.

## [0.10.0] - 2019-04-16

## [0.10.0-rc.0] - 2019-04-03
### Added
- [data_updater_plant] Add missing support to incoming object aggregated data with explicit_timestamp.

## [0.10.0-beta.3] - 2018-12-19
### Added
- [appengine_api] Binary blobs and date time values handling when PUTing and POSTing on a server owned interface.

### Fixed
- docker-compose: Ensure CFSSL persists the CA when no external CA is provided.
- [data_updater_plant] Correctly handle Bson.UTC and Bson.Bin incoming data.
- [data_updater_plant] Fix crash when an interface that has been previously removed from the device introspection expires from cache.
- [data_updater_plant] Undecodable BSON payloads handling (handle Bson.Decoder.Error struct).
- [data_updater_plant] Discard invalid introspection payloads instead of crashing the data updater process.
- [realm_management_api] Correctly serialize triggers on the special "*" interface and device.

## [0.10.0-beta.2] - 2018-10-19
### Added
- Automatically add begin and end delimiters to authorization regular expressions.
- [appengine_api] Value type and size validation.
- [appengine_api] Option to enable HTTP compression.
- [data_updater_plant] Allow to expire old data using Cassandra TTL.
- [data_updater_plant] Publish set properties list to `/control/consumer/properties`.

### Fixed
- [appengine_api] Path was added twice in authorization path, resulting in failures in authorization.
- [appengine_api] POST to a datastream endpoint doesn't crash anymore.
- [data_updater_plant] Validate all incoming values before performing any further computation on them, to avoid crash loops.
- [data_updater_plant] Fix a bug preventing data triggers to be correctly loaded
- [realm_management] Interface update, it was applying a broken update.
- [realm_management_api] Do not reply "Internal Server Error" when trying to delete a non existing interface.

### Changed
- [appengine_api] "data" key is used instead of "value" when PUT/POSTing a value to an interface.
- [appengine_api] APPENGINE_MAX_RESULTS_LIMIT env var was renamed to APPENGINE_API_MAX_RESULTS_LIMIT.

## [0.10.0-beta.1] - 2018-08-10
### Added
- First Astarte release.
