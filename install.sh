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

function usage() {
    cat <<EOF
Usage: $0 [install|update|uninstall] [options]

Commands:
  install            Install Capsule Agent (default)
  update             Update Capsule Agent binary in-place
  uninstall          Remove Capsule Agent service and binary

Options:
  --version <tag>    Use a specific release tag (e.g. v0.1.1)
  --pre-release      Allow prerelease versions (default: true)
  --port <number>    API port used when generating capsule-agent.env (install only)
EOF
}

ACTION="install"
if [[ $# -gt 0 ]]; then
    case "$1" in
        install|update|uninstall|help|-h|--help)
            ACTION=$1
            shift
            if [[ "$ACTION" == "help" || "$ACTION" == "-h" || "$ACTION" == "--help" ]]; then
                usage
                exit 0
            fi
            ;;
    esac
fi

VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --help|-h)
            usage
            exit 0
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

function resolve_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "capsule-agent-linux-amd64"
            ;;
        aarch64)
            echo "capsule-agent-linux-arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $arch" >&2
            exit 1
            ;;
    esac
}

function get_release_tag() {
    local tag
    if [[ -n "$VERSION" ]]; then
        echo "✅ Using version: $VERSION"
        tag="$VERSION"
    else
        echo "✅ Using latest release"
        echo "📦 Getting release information..."
        if [[ "$USE_PRERELEASE" == true ]]; then
            echo "🔍 Including pre-releases in search..."
            tag=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases" | jq -r 'map(select(.prerelease == true or .prerelease == false)) | sort_by(.created_at) | reverse | .[0].tag_name')
        else
            echo "🔍 Looking for stable releases only..."
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
    trap 'rm -rf "$tmp_dir"' RETURN

    echo "📥 Downloading Capsule Agent ${release_tag}..."
    local download_url="https://github.com/$OWNER/$REPO/releases/download/${release_tag}/${binary_name}"
    local sig_url="${download_url}.sig"

    curl -sSL -o "$tmp_dir/$binary_name" "$download_url"
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
LXC_AGENT_ROOT_USER_PASSWORD=root
LXC_AGENT_CORS_ALLOW_ORIGINS=*
LXC_AGENT_SERVER_BASE_URL=http://localhost:$PORT
LXC_AGENT_REGISTRY_BASE_URL=https://capsule-registry.local-build.co
LXC_AGENT_SERVER_API_PORT=$PORT
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

[Install]
WantedBy=multi-user.target
EOF
}

function stop_service_if_exists() {
    if [[ -f "$SERVICE_FILE" ]]; then
        echo "🛑 Stopping Capsule Agent service..."
        systemctl stop "$SERVICE_NAME" || true
    fi
}

function start_service() {
    echo "🚀 Starting Capsule Agent service..."
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME.service"
    systemctl start "$SERVICE_NAME.service"
}

function ensure_service_running() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ Capsule Agent service is running"
    else
        echo "❌ Capsule Agent service failed to start" >&2
        systemctl status "$SERVICE_NAME.service" --no-pager || true
        exit 1
    fi
}

function install_capsule_agent() {
    ensure_requirements
    echo "🔧 Installing Capsule Agent..."
    local binary_name
    binary_name=$(resolve_arch)
    local release_tag
    release_tag=$(get_release_tag)
    echo "📌 Selected release: ${release_tag}"

    download_binary "$release_tag" "$binary_name"
    create_env_file
    create_service_file
    start_service
    ensure_service_running
}

function update_capsule_agent() {
    ensure_requirements
    echo "♻️  Updating Capsule Agent..."

    if [[ ! -x "$BINARY_PATH" ]]; then
        echo "❌ Capsule Agent is not installed. Run install first." >&2
        exit 1
    fi

    local binary_name
    binary_name=$(resolve_arch)
    local release_tag
    release_tag=$(get_release_tag)
    echo "📌 Selected release: ${release_tag}"

    stop_service_if_exists
    download_binary "$release_tag" "$binary_name"
    echo "� Restarting Capsule Agent service..."
    systemctl restart "$SERVICE_NAME.service"
    ensure_service_running
}

function uninstall_capsule_agent() {
    ensure_requirements
    echo "🧹 Uninstalling Capsule Agent..."

    stop_service_if_exists
    systemctl disable "$SERVICE_NAME.service" >/dev/null 2>&1 || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload

    rm -f "$BINARY_PATH"
    rm -f "$ENV_FILE"

    echo "✅ Capsule Agent removed"
}

case "$ACTION" in
    install)
        install_capsule_agent
        ;;
    update)
        update_capsule_agent
        ;;
    uninstall)
        uninstall_capsule_agent
        ;;
    *)
        usage
        exit 1
        ;;
esac
