# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- [astarte_data_updater_plant] Add support for device introspection triggers.
- [astarte_realm_management] Add support for device introspection triggers.
- [astarte_realm_management_api] Add support for device introspection triggers.

## [1.0.3] - 2022-07-04
### Fixed
- [astarte_appengine_api] Consider `allow_bigintegers` and `allow_safe_bigintegers` params
  when querying the root of individual datastream / properties interfaces.
  Fix [#630](https://github.com/astarte-platform/astarte/issues/630).
- [astarte_appengine_api] Correctly return 405 "Cannot write to device owned resource" when
  POSTing on device-owned interfaces. Fix [#264](https://github.com/astarte-platform/astarte/issues/264).
- [astarte_appengine_api] Correctly return 405 "Cannot write to read-only resource" when
  POSTing on incomplete paths of server-owned interfaces.
- [astarte_e2e] Fix ssl options handling so that the e2e client is aware of the CA.

### Changed
- [doc] Administrator Guide: bump cert-manager dependency to v1.7.0.
- [data_updater_plant] Increase the `declare_exchange` timeout to 60 sec.
- [data_updater_plant] Increase the `publish` timeout to 60 sec for the AMQPEventsProducer.
- [astarte_realm_management_api] Do not crash when receiving trigger errors.
  Fix [683](https://github.com/astarte-platform/astarte/issues/683).
- [astarte_e2e] Allow setting custom subjects for alerting emails.
- [astarte_e2e] Group in a single thread emails referencing the same failure_id.
- [astarte_appengine_api] Make property unset succeed independently of whether there exist a device
  session on the broker or not. Fix [#640](https://github.com/astarte-platform/astarte/issues/640).
- [astarte_data_updater_plant] Log the base64-encoded object when receiving an object
  with unexpected key.

## [1.0.2] - 2022-04-01
### Added
- [realm_management] Accept `retention` and `expiry` updates when updating the minor version of an
  interface.
- [astarte_realm_management_api] Allow synchronous requests for interface creation, update
  and deletion using the `async_operation` option. Default to async calls.
- [astarte_housekeeping_api] Allow synchronous requests for realm creation and deletion
  using the `async_operation` option. Default to async calls.

### Fixed
- [realm_management] Accept allowed mapping updates in object aggregated interfaces without
  crashing.
- [astarte_appengine_api] Handle server owned datetimearray values correctly.

### Changed
- [astarte_housekeeping] Allow to delete a realm only if all its devices are disconnected.
  Realm deletion can still only be enabled with an environment variable (defaults to disabled).
- Update CA store to 2022-03-21 version.

## [1.0.1] - 2021-12-17
### Added
- [data_updater_plant] Add handle_data duration metric.
- [doc] Add documentation for AstarteDefaultIngress.
- [doc] Add deprecation notice for AstarteVoyagerIngress.
- [doc] Add documentation for the handling of Astarte certificates.

### Changed
- [doc] Remove astartectl profiles from the possible deployment alternatives.

### Fixed
- [astarte_appengine_api] Correctly serialize events containing datetime and array values.
- [astarte_appengine_api] Do not fail when querying `datastream` interfaces data with `since`, 
`to`, `sinceAfter` params if result is empty. Fix [#552](https://github.com/astarte-platform/astarte/issues/552). 
- [astarte_appengine_api] Consider microseconds when using timestamps.
  Fix [#620](https://github.com/astarte-platform/astarte/issues/620).
- [astarte_appengine_api] Don't crash when removing an alias with non-existing tag. 
  Fix [495](https://github.com/astarte-platform/astarte/issues/495).
- [astarte_trigger_engine] Correctly serialize events containing datetime and array values.
- [astarte_data_updater_plant] Don't crash when receiving `binaryblobarray` and `datetimearray`
  values.
- Update Cyanide BSON library, in order to fix crash when handling ill-formed BSON arrays.

## [1.0.0] - 2021-06-30
### Added
- Add support for volatile triggers on interfaces with object aggregation.

### Changed
- Document future removal of Astarte Operator's support for Cassandra.
- Log application version when starting.

### Fixed
- [astarte_appengine_api] Fix the support for `null` values in interfaces, the fix contained in
`1.0.0-rc.0` was incomplete.

## [1.0.0-rc.0] - 2021-05-10
### Added
- [astarte_appengine_api] Add `/v1/<realm>/version` endpoint, returning the API application version.
- [astarte_realm_management_api] Add `/v1/<realm>/version` endpoint, returning the API application
  version.
- [astarte_pairing_api] Add `/v1/<realm>/version` endpoint, returning the API application
  version.
- [astarte_housekeeping_api] Add `/v1/version` endpoint, returning the API application
  version.

### Changed
- [astarte_realm_management] Make `amqp_routing_key` mandatory in AMQP actions.
- Update documentation for backing up and restoring Astarte.
- Update documentation for Operator's uninstall procedure.

### Fixed
- [astarte_appengine_api] Don't crash when an interface contains `null` values, just show them as
  `null` in the resulting JSON.
- [astarte_realm_management] Fix log noise due to Cassandra warnings when checking health 
  (see [#420](https://github.com/astarte-platform/astarte/issues/420)).

## [1.0.0-beta.2] - 2021-03-24
### Fixed
- [astarte_e2e] Fix alerting mechanism preventing "unknown" failures to be raised or linked.
- [astarte_appengine_api] Allow retrieving data from interfaces with parametric endpoint and object
  aggregation (see [#480](https://github.com/astarte-platform/astarte/issues/480)).
- [astarte_appengine_api] Encode binaryblob values with Base64 even if they are contained in an
  aggregate value.
- [astarte_trigger_engine] Encode binaryblob values with Base64 even if they are contained in an
  aggregate value.

### Changed
- [astarte_e2e] Client disconnections are responsible for triggering a mail alert.
- Run tests against RabbitMQ 3.8.14 and ScyllaDB 4.4-rc.4 / Cassandra 3.11.10.
- Update dependencies to latest available versions (see `mix.lock` files).
- Update Elixir to 1.11.4 and OTP to 23.2.
- Rename device `metadata` to `attributes`. *This requires a manual intervention on the database*,
  see the [Schema Changes](https://docs.astarte-platform.org/1.0/090-database.html#schema-changes)
  documentation for additional information.

## [1.0.0-beta.1] - 2021-02-16
### Fixed
- [astarte_appengine_api] Fix regression that made it impossible to use Astarte Channels.
- [astarte_appengine_api] Fix bug that prevented data publishing in object aggregated interfaces.
- [astarte_appengine_api] Fix regression that prevented properties to be set before the first
  connection of a device.
- [astarte_realm_management] Fix a bug that prevented AMQP triggers to be correctly installed.
- [astarte_data_updater_plant] Mark device as offline and send device_disconnected event when
  forcing a device disconnection.
- [astarte_data_updater_plant] Fix bug that blocked queues when trying to disconnect an already
  disconnected device.

### Added
- [astarte_housekeeping] Allow deleting a realm. The feature can be enabled with an environment
  variable (defaults to disabled).
- [astarte_data_updater_plant] Declare custom exchanges when an AMQP trigger is loaded.

### Changed
- [astarte_housekeeping_api] Remove format check on Cassandra datacenter name when a realm is
  created, the datacenter is just verified against the one present in the database.
- [housekeeping] Increase the delay between connection attempts to 1000 ms, for an overall number
  of 60 attempts.
- [data_updater_plant] Default the total queue count to 128, de facto exploiting multiqueue support.
- [data_updater_plant] Default the queue range end to 127.
- Update Phoenix to version 1.5.
- Rework metrics to reduce the clutter while monitoring astarte services.
- [realm_management] Allow updating doc, description and explicit_timestamp within mappings when
  bumping an interface minor.
- Remove postgresql dependency in `docker-compose`, make CFSSL stateless.
- Update Operator's documentation for install/upgrade/uninstall procedures.

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

## [0.11.5] - Unreleased
### Fixed
- [realm_management] Avoid deleting all interfaces sharing the same name by mistake, only the v0
  interface can be deleted.
- [data_updater_plant] Use a reasonable backoff time (at most around 5 minutes) when publishing 
  to RabbitMQ.

## [0.11.4] - 2021-01-26
### Fixed
- Avoid creating an `housekeeping_public.pem` directory if `docker-compose up` doesn't find the
  housekeeping keypair.
- [trigger_engine] Correctly handle triggers on binaryblob interfaces, serializing value with base64
  like appengine does.
- [data_updater_plant] Consider `database_retention_ttl` when inserting data on device owned
  aggregate interfaces.
- [realm_management] Do not allow `value_change`, `value_change_applied` and `path_removed`
  triggers on datastreams.
- [realm_management] Do not allow `/*` as match path when using `value_change` and
  `value_change_applied`. (workaround to https://github.com/astarte-platform/astarte/issues/513).
- [trigger_engine] Update certifi to 2.5.3 (includes 2020-11-13 mkcert.org full CA bundle).

## [0.11.3] - 2020-09-24

## [0.11.2] - 2020-08-14
### Added
- [trigger_engine] Add `ignore_ssl_errors` key in trigger actions, allowing to ignore SSL actions
  when delivering an HTTP trigger action.
- [trigger_engine] Update certifi to 2.5.2
- Update Elixir to 1.8.2

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
