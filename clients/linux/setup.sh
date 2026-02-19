#!/bin/bash
# PaqX Client for Linux - Standalone Setup & Management
# https://github.com/bolandi-org/paqx

PAQX_ROOT="/usr/local/paqx"
LIB_DIR="$PAQX_ROOT/lib"

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

# -- Install Client ----------------------------------------------------------
install_client() {
    echo -e "\n${BOLD}--- Client Configuration ---${NC}"
    read -p "  Server (IP:Port): " server_addr
    [ -z "$server_addr" ] && { log_error "Server address required!"; return 1; }

    read -p "  Encryption Key: " enc_key
    [ -z "$enc_key" ] && { log_error "Key required!"; return 1; }

    echo ""
    echo "  1) Simple (Fast mode, key only - recommended)"
    echo "  2) Automatic (Full optimized settings)"
    read -p "  Select [1]: " mode
    mode=${mode:-1}

    read -p "  Local SOCKS5 Port [1080]: " local_port
    local_port=${local_port:-1080}

    # Network detection
    log_info "Detecting network..."
    IFACE=$(scan_interface)
    LOCAL_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)
    [ -z "$LOCAL_IP" ] && LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    local gw_ip=$(ip route show default | awk '/default/ {print $3}')
    GW_MAC=""
    if [ -n "$gw_ip" ]; then
        GW_MAC=$(ip neigh show "$gw_ip" 2>/dev/null | awk '/lladdr/{print $5; exit}')
        if [ -z "$GW_MAC" ]; then
            ping -c 1 -W 2 "$gw_ip" >/dev/null 2>&1 || true
            sleep 1
            GW_MAC=$(ip neigh show "$gw_ip" 2>/dev/null | awk '/lladdr/{print $5; exit}')
        fi
    fi

    log_success "Interface: $IFACE"
    log_success "Local IP: $LOCAL_IP"
    log_success "Gateway MAC: $GW_MAC"

    # Generate config
    mkdir -p "$CONF_DIR"

    if [ "$mode" = "2" ]; then
        cat > "$CONF_FILE" <<EOF
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:${local_port}"

network:
  interface: "${IFACE}"
  ipv4:
    addr: "${LOCAL_IP}:0"
    router_mac: "${GW_MAC}"

server:
  addr: "${server_addr}"

transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    conn: 1
    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    wdelay: false
    acknodelay: true
    mtu: 1350
    rcvwnd: 1024
    sndwnd: 1024
    block: "aes"
    key: "${enc_key}"
    smuxbuf: 4194304
    streambuf: 2097152
    dshard: 10
    pshard: 3
EOF
    else
        cat > "$CONF_FILE" <<EOF
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:${local_port}"

network:
  interface: "${IFACE}"
  ipv4:
    addr: "${LOCAL_IP}:0"
    router_mac: "${GW_MAC}"

server:
  addr: "${server_addr}"

transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    key: "${enc_key}"
EOF
    fi

    log_success "Config saved: $CONF_FILE"

    # Create systemd service
    cat > "$SERVICE_FILE_LINUX" <<EOF
[Unit]
Description=PaqX Client
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH run -c $CONF_FILE
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable paqx
    systemctl start paqx

    echo ""
    log_success "PaqX Client is running!"
    echo -e "  SOCKS5 Proxy: ${YELLOW}127.0.0.1:${local_port}${NC}"
    echo ""
    read -n1 -s -r -p "Press any key..."
}

# -- Client Panel ------------------------------------------------------------
panel_client() {
    while true; do
        # Read config
        local srv_addr=""
        local socks_port=""
        if [ -f "$CONF_FILE" ]; then
            local section=""
            while IFS= read -r line; do
                case "$line" in
                    server:*) section="server" ;;
                    socks5:*|network:*|transport:*|log:*|role:*) section="" ;;
                esac
                if [ "$section" = "server" ]; then
                    case "$line" in
                        *addr:*) srv_addr=$(echo "$line" | grep -oP '"[^"]*"' | tr -d '"') ;;
                    esac
                fi
                case "$line" in
                    *listen:*) socks_port=$(echo "$line" | grep -oP '"[^"]*"' | tr -d '"') ;;
                esac
            done < "$CONF_FILE"
        fi

        # Status
        local is_running=false
        systemctl is-active --quiet paqx && is_running=true
        local is_enabled=$(systemctl is-enabled paqx 2>/dev/null)
        local status_str=""; if $is_running; then status_str="Running"; else status_str="Stopped"; fi
        local auto_str=""; [ "$is_enabled" = "enabled" ] && auto_str="Enabled" || auto_str="Disabled"
        local max_len=${#srv_addr}; [ ${#socks_port} -gt $max_len ] && max_len=${#socks_port}
        local card_w=$((max_len + 14)); [ $card_w -lt 38 ] && card_w=38
        local border=$(printf '%0.s-' $(seq 1 $card_w))

        clear
        echo -e "\n  ${BLUE}+===============================+${NC}"
        echo -e "  ${BLUE}|     PaqX Client  (Linux)      |${NC}"
        echo -e "  ${BLUE}+===============================+${NC}\n"
        echo -e "  ${CYAN}+${border}+${NC}"
        if $is_running; then
            echo -e "  ${CYAN}|${NC} Status:  ${GREEN}${status_str}${NC}$(printf '%*s' $((card_w - ${#status_str} - 11)) '')${CYAN}|${NC}"
        else
            echo -e "  ${CYAN}|${NC} Status:  ${RED}${status_str}${NC}$(printf '%*s' $((card_w - ${#status_str} - 11)) '')${CYAN}|${NC}"
        fi
        echo -e "  ${CYAN}|${NC} Auto:    $([ "$is_enabled" = "enabled" ] && echo "${GREEN}" || echo "${RED}")${auto_str}${NC}$(printf '%*s' $((card_w - ${#auto_str} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}+${border}+${NC}"
        echo -e "  ${CYAN}|${NC} Server:  ${YELLOW}${srv_addr}${NC}$(printf '%*s' $((card_w - ${#srv_addr} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}|${NC} SOCKS5:  ${YELLOW}${socks_port}${NC}$(printf '%*s' $((card_w - ${#socks_port} - 11)) '')${CYAN}|${NC}"
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
            2) journalctl -u paqx -n 30 --no-pager; read -n1 -s -r -p "Press any key..." ;;
            3) if systemctl is-active --quiet paqx; then systemctl stop paqx; log_success "Stopped."; else systemctl start paqx; log_success "Started."; fi; sleep 1 ;;
            4) systemctl restart paqx; log_success "Restarted."; sleep 1 ;;
            5) if [ "$(systemctl is-enabled paqx 2>/dev/null)" = "enabled" ]; then systemctl disable paqx; log_success "Disabled."; else systemctl enable paqx; log_success "Enabled."; fi; sleep 1 ;;
            6) show_settings; read -n1 -s -r -p "Press any key..." ;;
            7) update_core; read -n1 -s -r -p "Press any key..." ;;
            8) downgrade_core; read -n1 -s -r -p "Press any key..." ;;
            9) uninstall_client; exit 0 ;;
            0) exit 0 ;;
        esac
    done
}

# -- Settings ----------------------------------------------------------------
show_settings() {
    while true; do
        echo -e "\n${BOLD}--- Client Settings ---${NC}"
        echo "1) Change Server (IP:Port & Key)"
        echo "2) Change Local SOCKS5 Port"
        echo "3) Change Protocol Mode"
        echo "4) View Server Info"
        echo "5) Refresh Network"
        echo "0) Back"
        read -p "Select: " s_opt

        case $s_opt in
            1)
                read -p "New Server (IP:Port): " new_addr
                read -p "New Encryption Key: " new_key
                sed -i "/^server:/,/^[^ ]/{s|addr: .*|addr: \"$new_addr\"|}" "$CONF_FILE"
                sed -i "s/key: .*/key: \"$new_key\"/" "$CONF_FILE"
                log_success "Server config updated."
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            2)
                read -p "New Local Port [1080]: " new_port
                new_port=${new_port:-1080}
                sed -i "s/listen: .*/listen: \"127.0.0.1:$new_port\"/" "$CONF_FILE"
                log_success "Local port changed to $new_port."
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            3)
                echo -e "\n${YELLOW}--- Protocol Mode ---${NC}"
                echo "1) Simple (Fast mode, key only)"
                echo "2) Automatic (Optimized defaults)"
                read -p "Select: " pm

                local cur_key=$(grep 'key:' "$CONF_FILE" | head -1 | grep -oP '"[^"]*"' | tr -d '"')
                local head_content=$(sed '/^transport:/,$d' "$CONF_FILE")

                if [ "$pm" = "2" ]; then
                    cat > "$CONF_FILE" <<EOF
${head_content}
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    conn: 1
    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    wdelay: false
    acknodelay: true
    mtu: 1350
    rcvwnd: 1024
    sndwnd: 1024
    block: "aes"
    key: "${cur_key}"
    smuxbuf: 4194304
    streambuf: 2097152
    dshard: 10
    pshard: 3
EOF
                    log_success "Switched to Automatic mode."
                else
                    cat > "$CONF_FILE" <<EOF
${head_content}
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    key: "${cur_key}"
EOF
                    log_success "Switched to Simple mode."
                fi
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            4)
                echo ""
                local info_addr=""
                local info_key=""
                local info_socks=""
                if [ -f "$CONF_FILE" ]; then
                    local sec=""
                    while IFS= read -r ln; do
                        case "$ln" in
                            server:*) sec="server" ;;
                            socks5:*|network:*|transport:*|log:*|role:*) sec="" ;;
                        esac
                        if [ "$sec" = "server" ]; then
                            case "$ln" in
                                *addr:*) info_addr=$(echo "$ln" | grep -oP '"[^"]*"' | tr -d '"') ;;
                            esac
                        fi
                        case "$ln" in
                            *key:*) info_key=$(echo "$ln" | grep -oP '"[^"]*"' | tr -d '"') ;;
                            *listen:*) info_socks=$(echo "$ln" | grep -oP '"[^"]*"' | tr -d '"') ;;
                        esac
                    done < "$CONF_FILE"
                fi
                echo -e "  ${YELLOW}--- Current Server Info ---${NC}"
                echo -e "  Server:   ${CYAN}$info_addr${NC}"
                echo -e "  Key:      ${CYAN}$info_key${NC}"
                echo -e "  SOCKS5:   ${CYAN}$info_socks${NC}"
                echo ""
                read -n1 -s -r -p "Press any key..."
                ;;
            5)
                # Refresh Network
                echo ""
                log_info "Detecting network..."
                local new_iface=$(scan_interface)
                local new_ip=$(ip -4 addr show "$new_iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)
                [ -z "$new_ip" ] && new_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
                local new_gw_ip=$(ip route show default | awk '/default/ {print $3}')
                local new_mac=""
                if [ -n "$new_gw_ip" ]; then
                    new_mac=$(ip neigh show "$new_gw_ip" 2>/dev/null | awk '/lladdr/{print $5; exit}')
                    if [ -z "$new_mac" ]; then
                        ping -c 1 -W 2 "$new_gw_ip" >/dev/null 2>&1 || true
                        sleep 1
                        new_mac=$(ip neigh show "$new_gw_ip" 2>/dev/null | awk '/lladdr/{print $5; exit}')
                    fi
                fi

                echo ""
                echo -e "  ${YELLOW}--- Detected Network ---${NC}"
                echo -e "  Interface:   ${CYAN}$new_iface${NC}"
                echo -e "  Local IP:    ${CYAN}$new_ip${NC}"
                echo -e "  Gateway MAC: ${CYAN}$new_mac${NC}"
                echo ""
                read -p "  Apply these settings? (Y/n): " confirm
                if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then continue; fi

                sed -i "s|interface: .*|interface: \"$new_iface\"|" "$CONF_FILE"
                sed -i "s|router_mac: .*|router_mac: \"$new_mac\"|" "$CONF_FILE"
                sed -i "/ipv4:/,/router_mac:/{s|addr: .*|addr: \"$new_ip:0\"|}" "$CONF_FILE"

                log_success "Network settings updated."
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            0|*) return ;;
        esac
    done
}

# -- Uninstall ---------------------------------------------------------------
uninstall_client() {
    echo -e "${RED}${BOLD}WARNING: This will COMPLETELY remove PaqX Client.${NC}"
    echo ""
    echo "  This will remove:"
    echo "  - PaqX service (systemd)"
    echo "  - paqet binary"
    echo "  - All configuration files"
    echo "  - paqx script"
    echo ""
    read -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then return; fi

    # 1. Stop and remove service
    log_info "Stopping service..."
    systemctl stop paqx 2>/dev/null || true
    systemctl disable paqx 2>/dev/null || true
    rm -f "$SERVICE_FILE_LINUX"
    systemctl daemon-reload 2>/dev/null || true

    # 2. Kill any remaining paqet processes
    pkill -f "paqet" 2>/dev/null || true

    # 3. Remove files
    log_info "Removing files..."
    rm -f "$BINARY_PATH"
    rm -rf "$CONF_DIR"
    rm -rf "$PAQX_ROOT"
    rm -f "/usr/bin/paqx"
    rm -f "/usr/local/bin/paqx"

    echo ""
    log_success "PaqX Client completely uninstalled."
}

# -- Self Install ------------------------------------------------------------
cp "$0" /usr/bin/paqx 2>/dev/null; chmod +x /usr/bin/paqx 2>/dev/null

# -- Entry Point -------------------------------------------------------------
[ "$(id -u)" != "0" ] && { echo "Error: Must run as root!"; exit 1; }

if [ -f "$CONF_FILE" ] && grep -q 'role: "client"' "$CONF_FILE"; then
    panel_client
else
    clear
    echo -e "\n  ${BLUE}+===============================+${NC}"
    echo -e "  ${BLUE}|     PaqX Client  (Linux)      |${NC}"
    echo -e "  ${BLUE}+===============================+${NC}\n"

    # Install deps & binary
    if command -v apt-get >/dev/null; then apt-get update -y && apt-get install -y curl tar; fi
    download_binary_core

    # Run client install
    install_client

    panel_client
fi
