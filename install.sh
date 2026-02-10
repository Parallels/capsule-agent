#!/bin/bash

set -euo pipefail

if [ -z "${USER:-}" ]; then
    USER=root
fi

OWNER="Parallels"
REPO="capsule-agent"
PORT=5000
USE_PRERELEASE=true
SERVICE_NAME="capsule-agent"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
BINARY_PATH="/usr/local/bin/${SERVICE_NAME}"
ENV_FILE="/usr/local/bin/${SERVICE_NAME}.env"
HARDWARE_ID="unknown"
APPLICATION_ID="unknown"
USER_ID="unknown"
PD_LICENSE="unknown"
PD_LICENSE_TYPE="unknown"
PD_LICENSE_IS_TRIAL="unknown"
PD_LICENSE_IS_VOLUME="unknown"
PD_ID="unknown"
ENVIRONMENT="stable"
CADDY_DOMAIN="parallels.internal"
MARKETPLACE_REGISTRY_URL="https://capsules-registry.parallels.com"
ROOT_PASSWORD="root"

function usage() {
    cat <<EOF >&2
Usage: $0 [install|update|uninstall] [options]

Commands:
  install            Install Capsule Agent (default)
  update             Update Capsule Agent binary in-place
  self-update        Update the binary only (used by auto-updater)
  uninstall          Remove Capsule Agent service and binary

Options:
  --version <tag>    Use a specific release tag (e.g. v0.1.1)
  --pre-release      Allow prerelease versions (default: true)
  --port <number>    API port used when generating capsule-agent.env (install only)
  --caddy-domain <domain> Domain to use for Caddy (default: parallels.internal)
  --marketplace-url <url> Marketplace registry URL (default: https://capsules-registry.parallels.com)
  --root-password <password> Root user password (default: root)
EOF
}

ACTION="install"
VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        install|update|self-update|uninstall|help|-h|--help)
            ACTION=$1
            shift
            if [[ "$ACTION" == "help" || "$ACTION" == "-h" || "$ACTION" == "--help" ]]; then
                usage
                exit 0
            fi
            ;;
        --user-id)
            USER_ID="$2"
            shift 2
            ;;
        --hardware-id)
            HARDWARE_ID="$2"
            shift 2
            ;;
        --application-id)
            APPLICATION_ID="$2"
            shift 2
            ;;
        --pd-license)
            PD_LICENSE="$2"
            shift 2
            ;;
        --pd-license-type)
            PD_LICENSE_TYPE="$2"
            shift 2
            ;;
        --pd-license-is-trial)
            PD_LICENSE_IS_TRIAL="$2"
            shift 2
            ;;
        --pd-license-is-volume)
            PD_LICENSE_IS_VOLUME="$2"
            shift 2
            ;;
        --pd-id)
            PD_ID="$2"
            shift 2
            ;;
        --pre-release)
            USE_PRERELEASE=true
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --caddy-domain)
            CADDY_DOMAIN="$2"
            shift 2
            ;;
        --marketplace-url)
            MARKETPLACE_REGISTRY_URL="$2"
            shift 2
            ;;
        --root-password)
            ROOT_PASSWORD="$2"
            shift 2
            ;;
        --telemetry-user-id)
            USER_ID="$2"
            shift 2
            ;;
        --telemetry-hardware-id)
            HARDWARE_ID="$2"
            shift 2
            ;;
        --telemetry-application-id)
            APPLICATION_ID="$2"
            shift 2
            ;;
        --telemetry-pd-license)
            PD_LICENSE="$2"
            shift 2
            ;;
        --telemetry-pd-license-type)
            PD_LICENSE_TYPE="$2"
            shift 2
            ;;
        --telemetry-pd-license-is-trial)
            PD_LICENSE_IS_TRIAL="$2"
            shift 2
            ;;
        --telemetry-pd-license-is-volume)
            PD_LICENSE_IS_VOLUME="$2"
            shift 2
            ;;
        --telemetry-pd-id)
            PD_ID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

function ensure_requirements() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl is required" >&2
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ jq is required" >&2
        exit 1
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "❌ systemctl is required" >&2
        exit 1
    fi
}

function resolve_binary_name() {
    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s)
    local binary_suffix=""

    case "$os" in
        Linux)
            binary_suffix="linux"
            ;;
        Darwin)
            binary_suffix="darwin"
            ;;
        *)
            echo "❌ Unsupported OS: $os" >&2
            exit 1
            ;;
    esac

    case "$arch" in
        x86_64)
            binary_suffix="${binary_suffix}-amd64"
            ;;
        aarch64|arm64)
            binary_suffix="${binary_suffix}-arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $arch" >&2
            exit 1
            ;;
    esac

    echo "${SERVICE_NAME}-${binary_suffix}"
}

function get_release_tag() {
    local tag
    if [[ -n "$VERSION" ]]; then
        echo "✅ Using version: $VERSION" >&2
        tag="$VERSION"
    else
        echo "✅ Using latest release" >&2
        echo "📦 Getting release information..." >&2
        if [[ "$USE_PRERELEASE" == true ]]; then
            echo "🔍 Including pre-releases in search..." >&2
            tag=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases" | jq -r 'map(select(.prerelease == true or .prerelease == false)) | sort_by(.created_at) | reverse | .[0].tag_name')
        else
            echo "🔍 Looking for stable releases only..." >&2
            tag=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | jq -r '.tag_name')
        fi
    fi

    if [[ -z "$tag" || "$tag" == "null" ]]; then
        echo "❌ Failed to get release information" >&2
        exit 1
    fi

    echo "$tag"
}

function download_binary() {
    local release_tag=$1
    local binary_name=$2
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap '[ -n "${tmp_dir:-}" ] && rm -rf "$tmp_dir"' RETURN

    echo "📥 Downloading Capsule Agent ${release_tag}..." >&2
    local download_url="https://github.com/$OWNER/$REPO/releases/download/${release_tag}/${binary_name}"
    local sig_url="${download_url}.sig"
    
    curl -sSL -o "$tmp_dir/$binary_name" "$download_url"
    
    local extracted_binary=""
    
    # Try to detect if it's a tarball
    if tar -tzf "$tmp_dir/$binary_name" >/dev/null 2>&1; then
        echo "📦 Detected tar.gz archive, extracting..." >&2
        mv "$tmp_dir/$binary_name" "$tmp_dir/$binary_name.tar.gz"
        tar -xzf "$tmp_dir/$binary_name.tar.gz" -C "$tmp_dir"
        
        # 1. Exact match of SERVICE_NAME
        if [[ -f "$tmp_dir/$SERVICE_NAME" ]]; then
            extracted_binary="$tmp_dir/$SERVICE_NAME"
        # 2. Exact match of binary_name
        elif [[ -f "$tmp_dir/$binary_name" ]]; then
             extracted_binary="$tmp_dir/$binary_name"
        else
            # 3. Regex match for service name prefix
            local regex_match
            regex_match=$(find "$tmp_dir" -maxdepth 1 -type f -name "${SERVICE_NAME}*" | head -n 1)
             if [[ -n "$regex_match" ]]; then
                extracted_binary="$regex_match"
            else
                # 4. Fallback search
                 extracted_binary=$(find "$tmp_dir" -maxdepth 1 -type f -perm +111 -not -name "*.tar.gz" -not -name "*.tgz" -not -name "*.zip" | head -n 1)
            fi
        fi

    # Try to detect if it's a zip
    elif unzip -tq "$tmp_dir/$binary_name" >/dev/null 2>&1; then
        echo "📦 Detected zip archive, extracting..." >&2
        mv "$tmp_dir/$binary_name" "$tmp_dir/$binary_name.zip"
        unzip -q -o "$tmp_dir/$binary_name.zip" -d "$tmp_dir"
        
        # 1. Exact match of SERVICE_NAME
        if [[ -f "$tmp_dir/$SERVICE_NAME" ]]; then
            extracted_binary="$tmp_dir/$SERVICE_NAME"
        # 2. Exact match of binary_name
        elif [[ -f "$tmp_dir/$binary_name" ]]; then
             extracted_binary="$tmp_dir/$binary_name"
        else
            # 3. Regex match for service name prefix
            local regex_match
            regex_match=$(find "$tmp_dir" -maxdepth 1 -type f -name "${SERVICE_NAME}*" | head -n 1)
             if [[ -n "$regex_match" ]]; then
                extracted_binary="$regex_match"
            else
                # 4. Fallback search
                 extracted_binary=$(find "$tmp_dir" -maxdepth 1 -type f -perm +111 -not -name "*.tar.gz" -not -name "*.tgz" -not -name "*.zip" | head -n 1)
            fi
        fi

    else
        # It's likely the binary itself
        extracted_binary="$tmp_dir/$binary_name"
    fi

    # If we extracted an archive and found a binary, or if it was a direct download
    if [[ -z "$extracted_binary" || ! -f "$extracted_binary" ]]; then
        echo "❌ Failed to find binary in archive or download failed" >&2
        ls -la "$tmp_dir" >&2
        exit 1
    fi
    
    echo "✅ Found binary: $extracted_binary" >&2
    if [[ "$extracted_binary" != "$tmp_dir/$binary_name" ]]; then
        mv "$extracted_binary" "$tmp_dir/$binary_name"
    fi

    # Signature download
    curl -sSL -o "$tmp_dir/${binary_name}.sig" "$sig_url"

    # TODO: Add signature verification here if needed

    chmod +x "$tmp_dir/$binary_name"
    mv "$tmp_dir/$binary_name" "$BINARY_PATH"
    rm -f "$tmp_dir/${binary_name}.sig"
}

function create_env_file() {
    cat <<EOF > "$ENV_FILE"
LXC_AGENT_DATABASE_MIGRATE=true
LXC_AGENT_ROOT_USER_USERNAME=root
LXC_AGENT_ROOT_USER_PASSWORD=$ROOT_PASSWORD
LXC_AGENT_CORS_ALLOW_ORIGINS=*
LXC_AGENT_SERVER_BASE_URL=http://localhost:$PORT
LXC_AGENT_MARKETPLACE_REGISTRY_BASE_URL=$MARKETPLACE_REGISTRY_URL
LXC_AGENT_SERVER_API_PORT=$PORT
LXC_AGENT_USER_ID=$USER_ID
LXC_AGENT_TELEMETRY_HARDWARE_ID=$HARDWARE_ID
LXC_AGENT_TELEMETRY_APPLICATION_ID=$APPLICATION_ID
LXC_AGENT_TELEMETRY_USER_ID=$USER_ID
LXC_AGENT_TELEMETRY_PD_LICENSE=$PD_LICENSE
LXC_AGENT_TELEMETRY_PD_LICENSE_TYPE=$PD_LICENSE_TYPE
LXC_AGENT_TELEMETRY_PD_LICENSE_IS_TRIAL=$PD_LICENSE_IS_TRIAL
LXC_AGENT_TELEMETRY_PD_LICENSE_IS_VOLUME=$PD_LICENSE_IS_VOLUME
LXC_AGENT_TELEMETRY_PD_ID=$PD_ID
LXC_AGENT_APP_ENVIRONMENT=$ENVIRONMENT
LXC_AGENT_CADDY_DEFAULT_DOMAIN=$CADDY_DOMAIN
EOF
}

function create_service_file() {
    tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Capsule Agent Service
After=network-online.target lxc-net.service
Wants=network-online.target
Requires=lxc-net.service

[Service]
Type=simple
ExecStart=${BINARY_PATH} -env ${ENV_FILE}
Restart=always
RestartSec=10
User=root

StandardOutput=append:/var/log/capsule-agent.log
StandardError=append:/var/log/capsule-agent.log

[Install]
WantedBy=multi-user.target
EOF
}

function stop_service_if_exists() {
    if [[ -f "$SERVICE_FILE" ]]; then
        echo "🛑 Stopping Capsule Agent service..." >&2
        systemctl stop "$SERVICE_NAME" || true
    fi
}

function start_service() {
    echo "🚀 Starting Capsule Agent service..." >&2
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME.service"
    systemctl start "$SERVICE_NAME.service"
}

function ensure_service_running() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ Capsule Agent service is running" >&2
    else
        echo "❌ Capsule Agent service failed to start" >&2
        systemctl status "$SERVICE_NAME.service" --no-pager || true
        exit 1
    fi
}

function install_capsule_agent() {
    ensure_requirements
    echo "🔧 Installing Capsule Agent..." >&2
    local binary_name
    binary_name=$(resolve_binary_name)
    local release_tag
    release_tag=$(get_release_tag)
    echo "📌 Selected release: ${release_tag}"

    download_binary "$release_tag" "$binary_name"
    create_env_file
    create_service_file
    start_service
    ensure_service_running
}

function update_env_value() {
    local key="$1"
    local value="$2"
    if [[ -f "$ENV_FILE" ]] && [[ -n "$value" ]]; then
        if grep -q "^${key}=" "$ENV_FILE"; then
            sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
            echo "  ✓ Updated $key" >&2
        else
            echo "${key}=${value}" >> "$ENV_FILE"
            echo "  ✓ Added $key" >&2
        fi
    fi
}

function update_env_file_if_needed() {
    echo "📝 Checking for environment updates..." >&2
    local updated=false

    if [[ "$MARKETPLACE_REGISTRY_URL" != "https://capsules-registry.parallels.com" ]] && [[ -n "$MARKETPLACE_REGISTRY_URL" ]]; then
        update_env_value "LXC_AGENT_MARKETPLACE_REGISTRY_BASE_URL" "$MARKETPLACE_REGISTRY_URL"
        updated=true
    fi
    if [[ "$ROOT_PASSWORD" != "root" ]] && [[ -n "$ROOT_PASSWORD" ]]; then
        update_env_value "LXC_AGENT_ROOT_USER_PASSWORD" "$ROOT_PASSWORD"
        updated=true
    fi
    if [[ "$USER_ID" != "unknown" ]] && [[ -n "$USER_ID" ]]; then
        update_env_value "LXC_AGENT_USER_ID" "$USER_ID"
        update_env_value "LXC_AGENT_TELEMETRY_USER_ID" "$USER_ID"
        updated=true
    fi
    if [[ "$HARDWARE_ID" != "unknown" ]] && [[ -n "$HARDWARE_ID" ]]; then
        update_env_value "LXC_AGENT_TELEMETRY_HARDWARE_ID" "$HARDWARE_ID"
        updated=true
    fi
    if [[ "$APPLICATION_ID" != "unknown" ]] && [[ -n "$APPLICATION_ID" ]]; then
        update_env_value "LXC_AGENT_TELEMETRY_APPLICATION_ID" "$APPLICATION_ID"
        updated=true
    fi
    if [[ "$PD_LICENSE" != "unknown" ]] && [[ -n "$PD_LICENSE" ]]; then
        update_env_value "LXC_AGENT_TELEMETRY_PD_LICENSE" "$PD_LICENSE"
        updated=true
    fi
    if [[ "$PD_LICENSE_TYPE" != "unknown" ]] && [[ -n "$PD_LICENSE_TYPE" ]]; then
        update_env_value "LXC_AGENT_TELEMETRY_PD_LICENSE_TYPE" "$PD_LICENSE_TYPE"
        updated=true
    fi
    if [[ "$PD_LICENSE_IS_TRIAL" != "unknown" ]] && [[ -n "$PD_LICENSE_IS_TRIAL" ]]; then
        update_env_value "LXC_AGENT_TELEMETRY_PD_LICENSE_IS_TRIAL" "$PD_LICENSE_IS_TRIAL"
        updated=true
    fi
    if [[ "$PD_LICENSE_IS_VOLUME" != "unknown" ]] && [[ -n "$PD_LICENSE_IS_VOLUME" ]]; then
        update_env_value "LXC_AGENT_TELEMETRY_PD_LICENSE_IS_VOLUME" "$PD_LICENSE_IS_VOLUME"
        updated=true
    fi
    if [[ "$PD_ID" != "unknown" ]] && [[ -n "$PD_ID" ]]; then
        update_env_value "LXC_AGENT_TELEMETRY_PD_ID" "$PD_ID"
        updated=true
    fi
    if [[ "$ENVIRONMENT" != "stable" ]] && [[ -n "$ENVIRONMENT" ]]; then
        update_env_value "LXC_AGENT_APP_ENVIRONMENT" "$ENVIRONMENT"
        updated=true
    fi
    if [[ "$CADDY_DOMAIN" != "parallels.internal" ]] && [[ -n "$CADDY_DOMAIN" ]]; then
        update_env_value "LXC_AGENT_CADDY_DEFAULT_DOMAIN" "$CADDY_DOMAIN"
        updated=true
    fi
    if [[ "$PORT" != "5000" ]] && [[ -n "$PORT" ]]; then
        update_env_value "LXC_AGENT_SERVER_API_PORT" "$PORT"
        update_env_value "LXC_AGENT_SERVER_BASE_URL" "http://localhost:$PORT"
        updated=true
    fi

    if [[ "$updated" == "false" ]]; then
        echo "  No environment updates needed" >&2
    fi
}

function update_capsule_agent() {
    ensure_requirements
    echo "♻️  Updating Capsule Agent..." >&2
    
    if [[ ! -x "$BINARY_PATH" ]]; then
        echo "❌ Capsule Agent is not installed. Run install first." >&2
        exit 1
    fi

    local binary_name
    binary_name=$(resolve_binary_name)
    local release_tag
    release_tag=$(get_release_tag)
    echo "📌 Selected release: ${release_tag}" >&2

    stop_service_if_exists
    download_binary "$release_tag" "$binary_name"
    update_env_file_if_needed
    echo "🔄 Restarting Capsule Agent service..." >&2
    systemctl restart "$SERVICE_NAME.service"
    ensure_service_running
}

function uninstall_capsule_agent() {
    ensure_requirements
    echo "🧹 Uninstalling Capsule Agent..." >&2

    stop_service_if_exists
    systemctl disable "$SERVICE_NAME.service" >/dev/null 2>&1 || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload

    rm -f "$BINARY_PATH"
    rm -f "$ENV_FILE"

    echo "✅ Capsule Agent removed" >&2
}

function self_update_capsule_agent() {
    ensure_requirements
    echo "♻️  Self-updating Capsule Agent..." >&2

    if [[ ! -x "$BINARY_PATH" ]]; then
        echo "❌ Capsule Agent is not installed. Run install first." >&2
        exit 1
    fi

    local binary_name
    binary_name=$(resolve_binary_name)
    local release_tag
    release_tag=$(get_release_tag)
    echo "📌 Selected release: ${release_tag}" >&2

    stop_service_if_exists
    download_binary "$release_tag" "$binary_name"

    echo "🔄 Restarting Capsule Agent service..." >&2
    start_service
    ensure_service_running
}

case "$ACTION" in
    install)
        install_capsule_agent
        ;;
    update)
        update_capsule_agent
        ;;
    self-update)
        self_update_capsule_agent
        ;;
    uninstall)
        uninstall_capsule_agent
        ;;
    *)
        usage
        exit 1
        ;;
esac
