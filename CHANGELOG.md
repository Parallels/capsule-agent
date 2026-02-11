# Changelog - Capsule Agent

All notable changes to the Capsule Agent module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.40] - 2026-02-11

- Fixed an issue with the volumes not being able to be set
- Added global network and volumes to the configuration tab
- fixes an issue with the combo box
- updates some UI related to the services
- Added some extra capsules
- Fixed an issue where the technical feedback was going to the wrong channel

## [0.1.39] - 2026-02-10



## [0.1.38] - 2026-02-10



## [0.1.37] - 2026-02-10



## [0.1.36] - 2026-02-10



## [0.1.35] - 2026-02-09



## [0.1.34] - 2026-02-09



## [0.1.33] - 2026-02-09



## [0.1.32] - 2026-02-09

- Added a new dialog for confirming why we are asking for passwords
- Fixed an issue where we requested too many times for the root password
- Updated the updater to use channels
- Updated the capsule agent and updater install scripts
- Moved the capsule updater to also use the registry update endpoint  

## [0.1.31] - 2026-02-06

- Fixed an issue where we were not able to disable https and use of the secure app
- Fixed an issue in one of the endpoints where a lxc service would fail to update
- Added the new ui-library module so we can share the UI between the capsule-marketplace, capsules-hub and others in the future
- Moved the capsule-marketplace to use the new ui-lib

## [0.1.30] - 2026-01-28

- Added a channel selection to the settings to decide the update channel
- Added a dynamic updater mechanism, fixes #142
- Removed the checkbox in the end of the technical feedback, fixes #138
- Fixed an issue with the notification polling using the wrong url
- Fixed an error on the app-feedback using the wrong type
- fixed an error where the technical report woul not use the right endpoint
- Reworked DNS resolver
- Further improvements in the Marketplace
- Fixed a bug where you were not able to install a application that you had searched in the apps
- Further stabilisation of the system
- Added extra fields for the capsules blueprint

## [0.1.29] - 2026-01-19

## [0.1.28] - 2026-01-19

## [0.1.27] - 2026-01-15

- Improved the way we deal with user feedback
- Added extra fields to the Capsules #118
- Added the new marketplace application #116
- Added a recovery for DNS issues with dnsmasq
- Added a new wait for the app to be ready
- Added better usage of urls when opening the page
- Added the new links to the marketplace

## [0.1.26] - 2025-12-19

- Added a new flow for the user when they have a application that requires credentials, fix #106
- Fixed an issue where a modal error was showing in the wrong place #105
- Fixed some minor issues with the UI, fix #109
- Fixed an issue where Onboarding would failed for users that had used old capsules app
- Fixed an issue where the marketplace would crash if two users had an empty email
- Fixed issues with the users database constrains
- Updated install scripts to not overwrite the existing .env file

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
