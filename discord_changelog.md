## What's Changed in capsule-agent v0.1.12-canary

Base version (stripped): 0.1.12
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

### Installation

Download the appropriate package for your platform from the [release assets](https://github.com/Parallels/capsule-agent/releases/tag/v0.1.12-canary).

### Links
- **Public Repository**: [github.com/Parallels/capsule-agent](https://github.com/Parallels/capsule-agent)
- **Monorepo Release**: [capsule-agent-v0.1.12-canary](https://github.com/Parallels-Corp/capsule-manager/releases/tag/capsule-agent-v0.1.12-canary)
