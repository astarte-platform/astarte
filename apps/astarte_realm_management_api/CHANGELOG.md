# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.10.2] - 2019-12-09
### Fixed
- Handle trigger not found reply from RPC, return 404 instead of 500.

## [0.10.1] - 2019-10-02
### Fixed
- Use updated interface validation: object aggregated properties interfaces are not valid.
- Use updated interface validation: server owned object aggregated interfaces are not yet supported, hence not valid.
- Trying to create a trigger with an already taken name now fails gracefully with an error instead of crashing.

## [0.10.0] - 2019-04-16

## [0.10.0-rc.0] - 2019-04-03

## [0.10.0-beta.3] - 2018-12-19
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
