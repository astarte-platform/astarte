# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.10.0-beta.2] - Unreleased
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
