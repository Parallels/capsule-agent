.PHONY: all build test clean run install lint fmt \
        help version version-get version-set increment-version \
        deps vet install-tools sign sign-custom build-and-sign \
        test-coverage upload-to-s3  build-docs serve-docs

# Default target
all: build

# Load .env if present (used for signing and distribution)
-include .env

# Binary name and output directory
OUT_DIR=out
BINARY_NAME=capsule-agent
BINARY=$(OUT_DIR)/$(BINARY_NAME)

# Backend signing variables
BACKEND_SIGNING_IDENTITY ?= $(if $(ENV_BACKEND_SIGNING_IDENTITY),$(ENV_BACKEND_SIGNING_IDENTITY),)
BACKEND_SIGNING_KEY_PATH ?= $(if $(ENV_BACKEND_SIGNING_KEY_PATH),$(ENV_BACKEND_SIGNING_KEY_PATH),)
BACKEND_SIGNING_KEY_PASSWORD ?= $(if $(ENV_BACKEND_SIGNING_KEY_PASSWORD),$(ENV_BACKEND_SIGNING_KEY_PASSWORD),)
BACKEND_NOTARIZATION_ENABLED ?= $(if $(ENV_BACKEND_NOTARIZATION_ENABLED),$(ENV_BACKEND_NOTARIZATION_ENABLED),false)

# S3 distribution variables
S3_BUCKET ?= $(if $(ENV_S3_BUCKET),$(ENV_S3_BUCKET),)
S3_REGION ?= $(if $(ENV_S3_REGION),$(ENV_S3_REGION),us-east-1)

# Module version from VERSION file
VERSION = $(shell cat VERSION 2>/dev/null || echo "unknown")

# Build information
BUILD_TIME = $(shell date -u '+%Y-%m-%d %H:%M:%S UTC')
GIT_COMMIT = $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Build flags for version injection
LDFLAGS = -ldflags "-X main.Version=$(VERSION) -X 'github.com/cjlapao/lxc-agent/pkg/version.BuildTime=$(BUILD_TIME)' -X github.com/cjlapao/lxc-agent/pkg/version.GitCommit=$(GIT_COMMIT)"

# Build the application
build:
	@mkdir -p $(OUT_DIR)
	go build $(LDFLAGS) -o $(BINARY) ./main.go

# Run the application
run: build
	./$(BINARY)

# Install dependencies
install:
	go mod tidy
	go mod download

deps: install

# Run tests
test:
	go test -v ./...

# Run tests with coverage
test-coverage:
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Clean build artifacts
clean:
	go clean
	rm -rf $(OUT_DIR)
	rm -f coverage.out coverage.html

# Format Go code
fmt:
	go fmt ./...

# Lint Go code
lint:
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not found. Install with 'make install-tools' or run 'go vet' for basic linting"; \
		go vet ./...; \
	fi

# Run go vet
vet:
	go vet ./...

# Install development tools
install-tools:
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Sign binary (macOS/Darwin only)
sign: build
	@echo "Signing $(BINARY_NAME) binary..."
	@if [ "$(shell uname)" = "Darwin" ]; then \
		if [ -n "$(BACKEND_SIGNING_IDENTITY)" ]; then \
			echo "Signing $(BINARY) with identity: $(BACKEND_SIGNING_IDENTITY)"; \
			codesign --force --sign "$(BACKEND_SIGNING_IDENTITY)" --timestamp --options runtime $(BINARY); \
			if [ "$(BACKEND_NOTARIZATION_ENABLED)" = "true" ]; then \
				echo "Submitting binary for notarization..."; \
				xcrun notarytool submit $(BINARY) --keychain-profile "notarytool-profile" --wait; \
			fi; \
		else \
			echo "Warning: BACKEND_SIGNING_IDENTITY not set. Skipping code signing."; \
		fi; \
	else \
		echo "Code signing is only supported on macOS. Skipping."; \
	fi

# Sign binary with custom certificate (for non-macOS or custom signing)
sign-custom: build
	@echo "Signing $(BINARY_NAME) binary with custom certificate..."
	@if [ -n "$(BACKEND_SIGNING_KEY_PATH)" ]; then \
		if command -v osslsigncode >/dev/null 2>&1; then \
			echo "Signing $(BINARY) with custom certificate"; \
			osslsigncode sign -certs "$(BACKEND_SIGNING_KEY_PATH)" -key "$(BACKEND_SIGNING_KEY_PATH)" -pass "$(BACKEND_SIGNING_KEY_PASSWORD)" -t http://timestamp.digicert.com -in $(BINARY) -out $(BINARY).signed && mv $(BINARY).signed $(BINARY); \
		else \
			echo "Error: osslsigncode not found. Install it for cross-platform signing."; \
			exit 1; \
		fi; \
	else \
		echo "Error: BACKEND_SIGNING_KEY_PATH not set. Cannot sign binary."; \
		exit 1; \
	fi

# Build and sign in one step (for CI/CD)
build-and-sign: build
	@echo "Building and signing $(BINARY_NAME) binary..."
	@if [ "$(shell uname)" = "Darwin" ] && [ -n "$(BACKEND_SIGNING_IDENTITY)" ]; then \
		$(MAKE) sign; \
	elif [ -n "$(BACKEND_SIGNING_KEY_PATH)" ]; then \
		$(MAKE) sign-custom; \
	else \
		echo "No signing configuration found. Binary built but not signed."; \
	fi

# Version management
version-get:
	@echo $(VERSION)

VERSION_TYPE ?= patch
version-set:
	@current_version="$(VERSION)"; \
	if [ "$$current_version" = "unknown" ]; then \
		echo "0.1.0" > VERSION; \
		echo "Created VERSION file with initial version 0.1.0"; \
	else \
		major=$$(echo "$$current_version" | cut -d'.' -f1); \
		minor=$$(echo "$$current_version" | cut -d'.' -f2); \
		patch=$$(echo "$$current_version" | cut -d'.' -f3); \
		case "$(VERSION_TYPE)" in \
			major) new_version="$$((major + 1)).0.0" ;; \
			minor) new_version="$$major.$$((minor + 1)).0" ;; \
			patch) new_version="$$major.$$minor.$$((patch + 1))" ;; \
			*) echo "Invalid VERSION_TYPE. Use major, minor, or patch."; exit 1 ;; \
		esac; \
		echo "$$new_version" > VERSION; \
		echo "Version updated from $$current_version to $$new_version"; \
	fi

increment-version: version-set

version:
	@echo "Current Capsule Agent version: $(VERSION)"
	@echo "Use 'make version-set [VERSION_TYPE=major|minor|patch]' to increment version"

# Upload to S3 (if configured)
upload-to-s3: build
	@if [ -z "$(S3_BUCKET)" ]; then \
		echo "Error: S3_BUCKET not configured. Set it in .env file."; \
		exit 1; \
	fi
	@echo "Uploading Capsule Agent binary to S3..."
	@if [ -f "$(BINARY)" ]; then \
		aws s3 cp $(BINARY) s3://$(S3_BUCKET)/capsule-agent/$(VERSION)/$(BINARY_NAME) --region $(S3_REGION); \
		echo "Upload completed to s3://$(S3_BUCKET)/capsule-agent/$(VERSION)/$(BINARY_NAME)"; \
	else \
		echo "Binary not found. Run 'make build' first."; \
		exit 1; \
	fi

# Show help
help:
	@echo "==============================================="
	@echo "Capsule Agent (Go) Makefile"
	@echo "==============================================="
	@echo ""
	@echo "BUILD COMMANDS:"
	@echo "  all               - Build the application (default)"
	@echo "  build             - Build the Go binary"
	@echo "  build-and-sign    - Build and sign binary (CI/CD friendly)"
	@echo ""
	@echo "RUN COMMANDS:"
	@echo "  run               - Build and run the application"
	@echo ""
	@echo "DEVELOPMENT COMMANDS:"
	@echo "  install           - Install and tidy Go dependencies"
	@echo "  deps              - Alias for install"
	@echo "  test              - Run all Go tests"
	@echo "  test-coverage     - Run tests with coverage report"
	@echo "  lint              - Run golangci-lint (or go vet if not available)"
	@echo "  fmt               - Format Go code with gofmt"
	@echo "  vet               - Run go vet static analysis"
	@echo "  clean             - Clean build artifacts"
	@echo "  install-tools     - Install development tools (golangci-lint)"
	@echo ""
	@echo "VERSION MANAGEMENT:"
	@echo "  version-get       - Show current version"
	@echo "  version-set       - Increment version (VERSION_TYPE=major|minor|patch)"
	@echo "  increment-version - Alias for version-set"
	@echo "  version           - Show version info and usage"
	@echo ""
	@echo "SIGNING & DISTRIBUTION:"
	@echo "  sign              - Sign binary (macOS/Apple only)"
	@echo "  sign-custom       - Sign binary with custom certificate"
	@echo "  upload-to-s3      - Upload binary to S3"
	@echo ""
	@echo "DOCUMENTATION:"
	@echo "  build-docs        - Build documentation"
	@echo "  serve-docs        - Serve documentation"
	@echo ""
	@echo "HELP:"
	@echo "  help              - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build test                    # Build and test"
	@echo "  make version-set VERSION_TYPE=minor  # Bump minor version"
	@echo "  make lint test                     # Run linting and tests"
	@echo "  make build-and-sign                # Build and sign binary"
	@echo ""
	@echo "VERSION INFORMATION:"
	@echo "  Current version: $(VERSION) (from VERSION file)"
	@echo "  Module: Capsule Agent"
	@echo "  Binary: $(BINARY_NAME)"
	@echo ""