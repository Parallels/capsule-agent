# Changelog - Capsule Agent

All notable changes to the Capsule Agent module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.25] - 2025-12-10



## [0.1.24] - 2025-12-04



## [0.1.23] - 2025-12-03

- Removed some duplicated go routines
- Improved stability on the monitoring
- Fix some issues with telemetry
- Fixed some memory leaks

## [0.1.22] - 2025-12-02

- Added new system variable to identify the docker host
- Fixed several issues with the flow of the capsule
- Added some new messages for the health check

## [0.1.21] - 2025-11-26



## [0.1.20] - 2025-11-25

- refactor of the UI components
- some fixes for the backend

## [0.1.13] - 2025-10-23

- Improved the design of the error dialog
- Fixed an issue where the error messages from the backend API would generate an error
- Enabled the debug messages in the log of the backend
- Fixed an issue in the install script that had the wrong variable name for the marketplace
- Fixed an issue in the search bar where it was not detecting empty strings and resetting the view

## [0.1.12] - 2025-10-20

- Modified release-capsule-marketplace-registry.yml to change environment descriptions and suffixes for canary and beta.
- Updated release-common-cleanup.yml to reflect new environment handling.
- Adjusted release-coordinator.yml to include canary and beta as options.
- Enhanced set-build-env.sh to propagate IS_CANARY and IS_BETA environment variables.
- Updated build.rs to embed IS_CANARY and IS_BETA into the build.
- Modified backend_manager.rs to handle service port dynamically and adjust health check URLs.
- Enhanced main.rs to set application configurations for canary and beta environments.
- Updated AppConfig interface to include isCanary and isBeta flags.
- Adjusted ConfigService to manage environment checks for canary and beta.
- Updated Makefiles for capsule-agent and capsule-agent-updater to include IS_BETA and IS_CANARY build flags.
- Enhanced telemetry to include environment and channel information.
- Added reset-application-hub.sh script for clearing user data and caches.
- Addressed a bug that could have stopped the way we started the app at first run
- Added a script to reset the application to the default to allow debugging
- Update codeowners
- Enhance markdownlint configuration
- Improve telemetry event naming
- Fixed missing telemetry from capsule-agent-updater
- Updated import paths in message_processor, telemetry, template, update, and updater packages to point to the new capsule-manager module.
- Ensured consistency across all files by replacing occurrences of "lxc-agent" with "capsule-manager".
- Added a CHANGELOG.md file to document notable changes and version history for the Capsule Agent.
- Created a Makefile for build automation, including commands for building, testing, linting, and version management.
- Implemented versioning with a VERSION file to track the current version of the Capsule Agent.
- Developed the main application entry point for the Capsule Agent, initializing necessary services and handling graceful shutdown.
- Introduced telemetry events for tracking application start and heartbeat events.

## [0.1.11] - 2025-10-16

- Enhance issue templates and workflows to extract changelog content for releases #38 

## [0.0.0] - 2024-08-26

- Initial release of Capsule Agent
