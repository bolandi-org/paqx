#!/bin/bash
[ -n "$_UTILS_SOURCED" ] && return 0
_UTILS_SOURCED=1

# --- UI Helpers ---

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "Must run as root!"
        exit 1
    fi
}

# --- Detection ---

detect_os() {
    OS="unknown"
    if [ -f /etc/openwrt_release ]; then
        OS="openwrt"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$ID"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    echo "$OS"
}

detect_arch() {
    # Check if we are on OpenWrt (use opkg)
    if command -v opkg >/dev/null 2>&1; then
        local OPKG_ARCH
        OPKG_ARCH=$(opkg print-architecture | grep -oE '(x86_64|aarch64|arm_cortex|mipsel|mips|arm)' | head -n 1)
        if [ -n "$OPKG_ARCH" ]; then
            case "$OPKG_ARCH" in
                x86_64) echo "amd64" ;;
                aarch64) echo "arm64" ;;
                arm_cortex*) echo "arm32" ;;
                mipsel*) echo "mipsle" ;;
                mips) echo "mips" ;;
                *) echo "unknown" ;;
            esac
            return
        fi
    fi

    local ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv7|armhf) echo "arm32" ;;
        mips64el|mips64le) echo "mips64le" ;;
        mips64) echo "mips64" ;;
        mipsel|mipsle) echo "mipsle" ;;
        mips) echo "mips" ;;
        *) echo "unknown" ;;
    esac
    esac
}

service_is_active() {
    OS_TYPE=$(detect_os)
    if [ "$OS_TYPE" = "openwrt" ]; then
        if /etc/init.d/paqx enabled >/dev/null 2>&1; then
            echo "enabled" # running logic in init.d depends, but enabled check works
        elif pgrep -f "$BINARY_PATH run" >/dev/null; then
            echo "active"
        else
            echo "inactive"
        fi
    else
        systemctl is-active paqx 2>/dev/null
    fi
}

service_is_enabled() {
    OS_TYPE=$(detect_os)
    if [ "$OS_TYPE" = "openwrt" ]; then
         /etc/init.d/paqx enabled && echo "enabled" || echo "disabled"
    else
        systemctl is-enabled paqx 2>/dev/null
    fi
}
