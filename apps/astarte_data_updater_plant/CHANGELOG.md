# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Add support to multiple queues with consistent hashing

### Changed
- Changed logs format to logfmt.

## [0.10.2] - Unreleased
### Changed
- Use the timestamp sent by VerneMQ (or explicit timestamp if available) to populate SimpleEvent timestamp.

### Fixed
- Do not accept invalid paths that have consecutive slashes.

## [0.10.1] - 2019-10-02
### Fixed
- Fix a bug that was causing a crash-loop in some corner cases when a message was sent on an outdated interface.
- Send consumer properties correctly when handling `emptyCache` control message.

## [0.10.0] - 2019-04-16

## [0.10.0-rc.0] - 2019-04-03
### Added
- Add missing support to incoming object aggregated data with explicit_timestamp.

## [0.10.0-beta.3] - 2018-12-19
### Fixed
- Correctly handle Bson.UTC and Bson.Bin incoming data.
- Fix crash when an interface that has been previously removed from the device introspection expires from cache.
- Undecodable BSON payloads handling (handle Bson.Decoder.Error struct).
- Discard invalid introspection payloads instead of crashing the data updater process.

## [0.10.0-beta.2] - 2018-10-19
### Added
- Allow to expire old data using Cassandra TTL.
- Publish set properties list to `/control/consumer/properties`.

### Fixed
- Validate all incoming values before performing any further computation on them, to avoid crash loops.
- Fix a bug preventing data triggers to be correctly loaded

## [0.10.0-beta.1] - 2018-08-10
### Added
- First Astarte release.
