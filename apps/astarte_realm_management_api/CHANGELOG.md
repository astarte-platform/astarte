# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- Authorization regular expressions must not have delimiters: they are implicit.

## [0.10.0-beta.3] - Unreleased
### Fixed
- Correctly serialize triggers on the special "*" interface and device.

## [0.10.0-beta.2] - 2018-10-19
### Added
- Automatically add begin and end delimiters to authorization regular expressions.

### Fixed
- Do not reply "Internal Server Error" when trying to delete a non existing interface.

## [0.10.0-beta.1] - 2018-08-10
### Added
- First Astarte release.
