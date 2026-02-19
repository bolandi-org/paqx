#!/bin/bash
[ -n "$_CORE_SOURCED" ] && return 0
_CORE_SOURCED=1

# --- Global Constants & Config ---

INSTALL_DIR="/usr/bin"
PAQX_ROOT="/usr/local/paqx"
LIB_DIR="$PAQX_ROOT/lib"
MODULES_DIR="$PAQX_ROOT/modules"
CONF_DIR="/etc/paqx"
CONF_FILE="$CONF_DIR/config.yaml"
SERVICE_FILE_LINUX="/etc/systemd/system/paqx.service"
SERVICE_FILE_OPENWRT="/etc/init.d/paqx"
BINARY_PATH="$INSTALL_DIR/paqet"
# Script Repo (for updates)
REPO_OWNER="bolandi-org"
REPO_NAME="paqx"

# Binary Repo (for paqet core)
BINARY_REPO_OWNER="hanselime"
BINARY_REPO_NAME="paqet"
VERSION="3.0.0"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Shared Helpers ---

revert_kernel() {
    rm -f /etc/sysctl.d/99-paqx.conf 2>/dev/null
    sysctl --system >/dev/null 2>&1 || true
}
