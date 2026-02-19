#!/bin/bash
# PaqX Server - Entry Point
# https://github.com/bolandi-org/paqx

PAQX_ROOT="/usr/local/paqx"
LIB_DIR="$PAQX_ROOT/lib"
MODULES_DIR="$PAQX_ROOT/modules"

# -- Bootstrap ---------------------------------------------------------------
bootstrap() {
    if [ ! -f "$LIB_DIR/core.sh" ]; then
        echo "Downloading PaqX..."
        [ "$(id -u)" != "0" ] && { echo "Error: Need root."; exit 1; }
        mkdir -p "$PAQX_ROOT"

        if command -v apt-get >/dev/null; then
            apt-get update -y >/dev/null 2>&1 && apt-get install -y curl tar >/dev/null 2>&1
        elif command -v yum >/dev/null; then
            yum install -y curl tar >/dev/null 2>&1
        elif command -v dnf >/dev/null; then
            dnf install -y curl tar >/dev/null 2>&1
        fi

        curl -L "https://github.com/bolandi-org/paqx/archive/refs/heads/main.tar.gz" -o /tmp/paqx.tar.gz
        [ $? -ne 0 ] && { echo "Error: Download failed."; exit 1; }
        tar -xzf /tmp/paqx.tar.gz -C "$PAQX_ROOT" --strip-components=1
        rm -f /tmp/paqx.tar.gz

        [ ! -f "$LIB_DIR/core.sh" ] && { echo "Error: Bootstrap failed."; exit 1; }
        echo "Bootstrap complete."
    fi
}

bootstrap

source "$LIB_DIR/core.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/crypto.sh"
source "$MODULES_DIR/server.sh"

# -- Download Binary ---------------------------------------------------------
download_binary_core() {
    local arch=$(detect_arch)
    local os_type="linux"
    log_info "Fetching latest binary release..."
    local b_owner="hanselime"
    local b_name="paqet"
    local release_json=$(curl -sL "https://api.github.com/repos/$b_owner/$b_name/releases/latest")
    local tag=$(echo "$release_json" | grep -oP '"tag_name": "\K(.*)(?=")')
    local dl_url=""
    if [ -n "$tag" ]; then
        dl_url=$(echo "$release_json" | grep "browser_download_url" | grep "$os_type" | grep "$arch" | cut -d '"' -f 4 | head -n 1)
        if [ -z "$dl_url" ]; then
            local clean_ver="${tag#v}"
            dl_url="https://github.com/$b_owner/$b_name/releases/download/$tag/paqet-$os_type-$arch-$clean_ver.tar.gz"
        fi
    else
        dl_url="https://github.com/$b_owner/$b_name/releases/latest/download/paqet-$os_type-$arch.tar.gz"
    fi
    log_info "Downloading: $dl_url"
    curl -L -f -o /tmp/paqet.tar.gz "$dl_url"
    [ $? -ne 0 ] && { log_error "Download failed."; return 1; }
    tar -xzf /tmp/paqet.tar.gz -C /tmp
    local bin=$(find /tmp -type f -name "paqet*" ! -name "*.tar.gz" | head -n 1)
    if [ -n "$bin" ] && [ -f "$bin" ]; then
        mkdir -p "$(dirname "$BINARY_PATH")"
        chmod +x "$bin"
        mv "$bin" "$BINARY_PATH"
        rm -f /tmp/paqet.tar.gz
        log_success "Core binary installed."
    else
        log_error "Binary not found in archive."
        return 1
    fi
}

update_core() {
    log_info "Updating Paqet binary..."
    download_binary_core
    [ $? -eq 0 ] && { log_info "Restarting..."; systemctl restart paqx; }
}

downgrade_core() {
    local b_owner="hanselime"
    local b_name="paqet"
    local arch=$(detect_arch)
    log_info "Fetching versions..."
    local releases_json=$(curl -sL "https://api.github.com/repos/$b_owner/$b_name/releases?per_page=10")
    local tags=($(echo "$releases_json" | grep -oP '"tag_name": "\K[^"]+'))
    [ ${#tags[@]} -eq 0 ] && { log_error "Could not fetch versions."; return 1; }
    echo -e "\n${BOLD}--- Select Version ---${NC}"
    for i in "${!tags[@]}"; do echo "$((i+1))) ${tags[$i]}"; done
    echo "0) Cancel"
    read -p "Select: " v_opt
    [ "$v_opt" = "0" ] || [ -z "$v_opt" ] && return
    local idx=$((v_opt-1))
    [ $idx -lt 0 ] || [ $idx -ge ${#tags[@]} ] && { log_error "Invalid."; return 1; }
    local sel_tag="${tags[$idx]}"
    local clean_ver="${sel_tag#v}"
    local dl_url="https://github.com/$b_owner/$b_name/releases/download/$sel_tag/paqet-linux-$arch-$clean_ver.tar.gz"
    log_info "Downloading $sel_tag..."
    curl -L -f -o /tmp/paqet.tar.gz "$dl_url"
    [ $? -ne 0 ] && { log_error "Download failed."; return 1; }
    tar -xzf /tmp/paqet.tar.gz -C /tmp
    local bin=$(find /tmp -type f -name "paqet*" ! -name "*.tar.gz" | head -n 1)
    if [ -n "$bin" ]; then
        chmod +x "$bin"; mv "$bin" "$BINARY_PATH"; rm -f /tmp/paqet.tar.gz
        log_success "Downgraded to $sel_tag."
        systemctl restart paqx
    else
        log_error "Binary not found."
    fi
}

# -- Server Panel ------------------------------------------------------------
panel_server() {
    local srv_ip=$(get_public_ip)
    while true; do
        local srv_port=$(grep 'addr: ":' "$CONF_FILE" 2>/dev/null | head -1 | grep -oP ':\K[0-9]+')
        local srv_key=$(grep 'key:' "$CONF_FILE" 2>/dev/null | head -1 | grep -oP '"[^"]*"' | tr -d '"')
        local is_running=false
        systemctl is-active --quiet paqx && is_running=true
        local is_enabled=$(systemctl is-enabled paqx 2>/dev/null)
        local status_str=""; if $is_running; then status_str="Running"; else status_str="Stopped"; fi
        local auto_str=""; [ "$is_enabled" = "enabled" ] && auto_str="Enabled" || auto_str="Disabled"
        local addr_str="${srv_ip}:${srv_port}"
        local key_str="${srv_key}"
        local max_len=${#addr_str}; [ ${#key_str} -gt $max_len ] && max_len=${#key_str}
        local card_w=$((max_len + 14)); [ $card_w -lt 38 ] && card_w=38
        local border=$(printf '%0.s-' $(seq 1 $card_w))

        clear
        echo -e "\n  ${BLUE}+===============================+${NC}"
        echo -e "  ${BLUE}|       PaqX Server Panel       |${NC}"
        echo -e "  ${BLUE}+===============================+${NC}\n"
        echo -e "  ${CYAN}+${border}+${NC}"
        if $is_running; then
            echo -e "  ${CYAN}|${NC} Status:  ${GREEN}${status_str}${NC}$(printf '%*s' $((card_w - ${#status_str} - 11)) '')${CYAN}|${NC}"
        else
            echo -e "  ${CYAN}|${NC} Status:  ${RED}${status_str}${NC}$(printf '%*s' $((card_w - ${#status_str} - 11)) '')${CYAN}|${NC}"
        fi
        echo -e "  ${CYAN}|${NC} Auto:    $([ "$is_enabled" = "enabled" ] && echo "${GREEN}" || echo "${RED}")${auto_str}${NC}$(printf '%*s' $((card_w - ${#auto_str} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}+${border}+${NC}"
        echo -e "  ${CYAN}|${NC} Address: ${YELLOW}${addr_str}${NC}$(printf '%*s' $((card_w - ${#addr_str} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}|${NC} Key:     ${YELLOW}${key_str}${NC}$(printf '%*s' $((card_w - ${#key_str} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}+${border}+${NC}"
        echo ""
        echo " 1) Status"
        echo " 2) Log"
        echo " 3) Start/Stop"
        echo " 4) Restart"
        echo " 5) Disable/Enable"
        echo " 6) Settings"
        echo " 7) Update Core"
        echo " 8) Downgrade Core"
        echo " 9) Uninstall"
        echo " 0) Exit"
        echo ""
        read -p "Select: " opt
        case $opt in
            1) systemctl status paqx --no-pager; read -n1 -s -r -p "Press any key..." ;;
            2) journalctl -u paqx -n 10 --no-pager; read -n1 -s -r -p "Press any key..." ;;
            3) if systemctl is-active --quiet paqx; then systemctl stop paqx; log_success "Stopped."; else systemctl start paqx; log_success "Started."; fi; sleep 1 ;;
            4) systemctl restart paqx; log_success "Restarted."; sleep 1 ;;
            5) if [ "$(systemctl is-enabled paqx 2>/dev/null)" = "enabled" ]; then systemctl disable paqx; log_success "Disabled."; else systemctl enable paqx; log_success "Enabled."; fi; sleep 1 ;;
            6) configure_server; read -n1 -s -r -p "Press any key..." ;;
            7) update_core; read -n1 -s -r -p "Press any key..." ;;
            8) downgrade_core; read -n1 -s -r -p "Press any key..." ;;
            9) remove_server; exit 0 ;;
            0) exit 0 ;;
        esac
    done
}

# -- Self Install ------------------------------------------------------------
cp "$0" /usr/bin/paqx 2>/dev/null; chmod +x /usr/bin/paqx 2>/dev/null

# -- Entry Point -------------------------------------------------------------
[ "$(id -u)" != "0" ] && { echo "Error: Must run as root!"; exit 1; }

if [ -f "$CONF_FILE" ] && grep -q 'role: "server"' "$CONF_FILE"; then
    panel_server
else
    clear
    echo -e "\n  ${BLUE}+===============================+${NC}"
    echo -e "  ${BLUE}|     PaqX Server  Setup        |${NC}"
    echo -e "  ${BLUE}+===============================+${NC}\n"

    # Install deps & binary
    if command -v apt-get >/dev/null; then apt-get update -y && apt-get install -y curl tar; fi
    download_binary_core

    # Run server install (from module)
    install_server

    read -n1 -s -r -p "Press any key..."
    panel_server
fi
