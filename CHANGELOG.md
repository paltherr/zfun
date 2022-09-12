# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased](https://github.com/paltherr/zfun/compare/latest...HEAD)

## [0.1.1](https://github.com/paltherr/zfun/releases/tag/v0.1.1) - 2022-09-12

### Added

- Description of release process in Releasing.md.

### Changed

- Improved error handling in `fun` and `var`.
- Improved test coverage of `fun` and `var`.
- Documented function `check` in [tests/zfun.bats](tests/zfun.bats).

### Fixed

- Bug https://github.com/paltherr/zfun/issues/1: `var` fails to overwrite local non-scalar variables.
- Bug https://github.com/paltherr/zfun/issues/2: `var` does nothing if `:=` isn't preceded by a space.

## [0.1.0](https://github.com/paltherr/zfun/releases/tag/v0.1.0) - 2022-04-12

### Added

- Initial public release.
