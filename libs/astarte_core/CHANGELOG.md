# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0-rc.0] - 2026-04-07

### Added

- Add required flag for mappings of object aggregated interfaces

## [1.3.0-rc.1] - 2026-01-23

### Fixed

- BREAKING: Trigger target decoding now returns the headers as a map instead of a list, in
  accordance with the typespec

## [1.3.0-rc.0] - 2025-10-20

### Added

- Device capabilities
- Device capability `purge_property_compression_format`
- Add events for device deletion started and finished.
- Add event for device registration.

## [1.2.1] - 2026-03-06

### Fixed
- [astarte_realm_management] Insufficient validation for conflicting options in interface aggregate mappings
  [#1072](https://github.com/astarte-platform/astarte/issues/1072)

## [1.2.1-rc.0] - 2025-08-22
### Added
- Allow `to_int` in custom enum types to be called with valid integers
- Allow `from_int` in custom enum types to be called with valid atoms
- Expose a custom `@type` for all structs
- Implement json encoder for `IncomingIntrospectionEvent`

## [1.2.0] - 2024-07-01

## [1.2.0-rc.0] - 2024-05-28

### Added

- Function for translating realm to keyspace, to support multiple Astarte
  instances sharing the same database
- Added device capabilities
- Added device capability `purge_property_compression_format`

### Changed

- Bump Elixir to 1.15.7.
- Bump Erlang/OTP to 26.1.
- IncomingIntrospectionEvent holds now a interface-name -> {major, minor} map
  instead of the plain introspection string.

## [1.1.1] - 2023-10-03

### Fixed

- Handle Cyanide 2.0 binaries correctly. Fix #95.
- Correctly encode binaryblobarrays in JSON payload of Astarte events.

## [1.1.0] - 2023-06-20

### Fixed

- Forward ported changes from 1.0.5 (Do not allow mappings where `database_retention_policy`...)

## [1.1.0-rc.0] - 2023-06-08

### Changed

- Bump Elixir and Erlang to 1.14.5 and 25.3.2, respectively.

## [1.1.0-alpha.0] - 2022-11-14

### Changed

- Extend interface mappings charset to support name prefixed with underscore
- Introspection triggers are part of device triggers. Expose an API closer to other triggers.

## [1.0.6] - 2024-04-18

## [1.0.5] - 2023-09-25

### Fixed

- Do not allow mappings where `database_retention_policy` is
  `use_ttl` but no ttl is set. Fix #84.

## [1.0.4] - 2022-09-26

### Added

- Add delivery policies to triggers.

## [1.0.3] - 2022-07-04

## [1.0.2] - 2022-03-29

## [1.0.1] - 2021-12-16

### Added

- Handle array values when decoding simple events

### Fixed

- Don't treat structs as object aggregations when decoding simple events

## [1.0.0] - 2021-06-28

## [1.0.0-rc.0] - 2021-05-05

## [1.0.0-beta.2] - 2021-03-23

### Changed

- Update dependencies and Elixir version to 1.11
- If `database_retention_policy` is set to `:no_ttl`, `database_retention_ttl` must not be set. (See #51)

### Fixed

- Correctly handle SimpleEvents JSON encoding even when they contain an object aggregation with a
  binaryblob value.

## [1.0.0-beta.1] - 2021-02-11

### Fixed

- Return an error instead of crashing when the endpoint is not present within a mapping.

## [1.0.0-alpha.1] - 2020-06-18

### Added

- Add `exchange` to `AMQPTriggerTarget` proto. This will allow to send events to any user defined
  AMQP exchange (see [#351](https://github.com/astarte-platform/astarte/issues/351)).
- Add additional options to `AMQPTriggerTarget` such as `priority`, `expiration` and `persistent`.
- Add support for device-specific and group-specific triggers.
- Add `DeviceErrorEvent` to `SimpleEvents`, allowing to react to a device error.

### Changed

- It is now possible to omit the `device_id` in a `device_trigger`. This is equivalent to passing
  `*` as `device_id`. The old behaviour is still supported.

## [0.11.4] - 2021-01-25

### Fixed

- Correctly handle binaryblob value deserialization in events.

## [0.11.3] - 2020-09-24

## [0.11.2] - 2020-08-14

### Changed

- Test against Elixir 1.8.2.

## [0.11.1] - 2020-05-18

## [0.11.0] - 2020-04-06

## [0.11.0-rc.1] - 2020-03-25

## [0.11.0-rc.0] - 2020-02-26

### Changed

- Add support for aggregated server owned interfaces.

### Fixed

- Correctly handle parametric endpoints regardless of the ordering, so that overlapping endpoints are always refused. (See #2)

## [0.11.0-beta.2] - 2020-01-24

### Changed

- Restrict the use of `*` as `interface_name` only to `incoming_data` data triggers.
- Allow hyphens in `interface_name`. Both the top level domain and the last domain component
  must not contain hyphens. ([#7](https://github.com/astarte-platform/astarte_core/issues/7))

### Fixed

- Handle empty `bson_value` in `Triggers.SimpleEvents.Encoder`, avoiding crashes when an empty bson
  value is sent as event (e.g. unset).

## [0.11.0-beta.1] - 2019-12-24

### Changed

- `astarte`, `system` and all names starting with `system_` are now reserved realm names.
- Add `database_retention_policy` and `database_retention_ttl` mapping attributes.

## [0.10.2] - 2019-12-09

### Added

- Add timestamp field to SimpleEvent protobuf.

## [0.10.1] - 2019-10-02

### Fixed

- Fix interface validation: object aggregated properties interfaces are not valid.
- Fix interface validation: server owned object aggregated interfaces are not yet supported, hence not valid.

## [0.10.0] - 2019-04-16

## [0.10.0-rc.0] - 2019-04-03

### Fixed

- Fix endpoint placeholder regex used in Mapping.normalize_endpoint.
- Fix overlapping endpoints detection, it was allowing some corner case overlappings.

## [0.10.0-beta.3] - 2018-12-19

### Changed

- Interface name `device` is reserved now.

### Fixed

- Correctly support Bson.Bin struct.
- False positive overlapping endpoints were detected, EndpointsAutomaton now handles them as valid.
- Correctly serialize triggers on the special "\*" interface and device.

## [0.10.0-beta.2] - 2018-10-19

### Added

- Add limit to 64K for string and blobs, 1024 items for arrays.
- Add value validation code for any Astarte type.

## [0.10.0-beta.1] - 2018-08-10

### Added

- First Astarte release.
