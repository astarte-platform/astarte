# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.2] - 2019-12-09
### Added
- Add timestamp field to channel events.

### Fixed
- Fix invalid dates handling, they should not cause an internal server error.
- Gracefully handle existing aliases instead of returning an internal server error.
- Fix querying object aggregated interface with explicit timestamp, use value_timestamp to avoid
an internal server error.
- Device details now show false in the connected field for never connected devices (null was
  returned before)
- Handle out-of-band RPC errors gracefully instead of crashing.

## [0.10.1] - 2019-10-02
### Fixed
- Auth was refusing any POST method, a workaround has been added, however this will not work with regex.
- Fix reversed order when sending binaryblobarray and datetimearray.

## [0.10.0] - 2019-04-16

## [0.10.0-rc.0] - 2019-04-03

## [0.10.0-beta.3] - 2018-12-19
### Added
- Binary blobs and date time values handling when PUTing and POSTing on a server owned interface.

## [0.10.0-beta.2] - 2018-10-19
### Added
- Automatically add begin and end delimiters to authorization regular expressions.
- Value type and size validation.
- Option to enable HTTP compression.

### Fixed
- Path was added twice in authorization path, resulting in failures in authorization.
- POST to a datastream endpoint doesn't crash anymore.

### Changed
- "data" key is used instead of "value" when PUT/POSTing a value to an interface.
- APPENGINE_MAX_RESULTS_LIMIT env var was renamed to APPENGINE_API_MAX_RESULTS_LIMIT.

## [0.10.0-beta.1] - 2018-08-10
### Added
- First Astarte release.
