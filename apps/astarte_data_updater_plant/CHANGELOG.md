# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.0-beta.3] - Unreleased
### Fixed
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
