#!/bin/sh
# PaqX Client for OpenWrt - Standalone Setup & Management
# https://github.com/bolandi-org/paqx

# -- Constants ---------------------------------------------------------------
INSTALL_DIR="/usr/bin"
CONF_DIR="/etc/paqet"
CONF_FILE="$CONF_DIR/config.yaml"
SERVICE_FILE="/etc/init.d/paqet"
BINARY_PATH="$INSTALL_DIR/paqet"
LOG_FILE="/tmp/paqx.log"
REPO_OWNER="hanselime"
REPO_NAME="paqet"
SCRIPT_PATH="/usr/bin/paqx"

# -- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# -- Helpers -----------------------------------------------------------------
write_ok()   { echo -e "${GREEN}[+] $1${NC}"; }
write_err()  { echo -e "${RED}[!] $1${NC}"; }
write_info() { echo -e "${YELLOW}[*] $1${NC}"; }
write_warn() { echo -e "${YELLOW}[!] $1${NC}"; }

prompt_manual_kcp() {
    local def_conn="1"; local def_nodelay="1"; local def_interval="10"; local def_resend="2"
    local def_nc="1"; local def_wdelay="false"; local def_ack="true"; local def_mtu="1350"
    local def_rcvwnd="1024"; local def_sndwnd="1024"; local def_block="aes"
    local def_smux="4194304"; local def_stream="2097152"; local def_dshard="10"; local def_pshard="3"

    if [ -f "$CONF_FILE" ]; then
        local val
        val=$(grep -E "^[[:space:]]+conn:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_conn="$val"
        val=$(grep -E "^[[:space:]]+nodelay:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_nodelay="$val"
        val=$(grep -E "^[[:space:]]+interval:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_interval="$val"
        val=$(grep -E "^[[:space:]]+resend:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_resend="$val"
        val=$(grep -E "^[[:space:]]+nocongestion:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_nc="$val"
        val=$(grep -E "^[[:space:]]+wdelay:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_wdelay="$val"
        val=$(grep -E "^[[:space:]]+acknodelay:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_ack="$val"
        val=$(grep -E "^[[:space:]]+mtu:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_mtu="$val"
        val=$(grep -E "^[[:space:]]+rcvwnd:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_rcvwnd="$val"
        val=$(grep -E "^[[:space:]]+sndwnd:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_sndwnd="$val"
        val=$(grep -E "^[[:space:]]+block:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_block="$val"
        val=$(grep -E "^[[:space:]]+smuxbuf:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_smux="$val"
        val=$(grep -E "^[[:space:]]+streambuf:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_stream="$val"
        val=$(grep -E "^[[:space:]]+dshard:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_dshard="$val"
        val=$(grep -E "^[[:space:]]+pshard:" "$CONF_FILE" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"\r')
        [ -n "$val" ] && def_pshard="$val"
    fi

    echo ""
    printf "  Conn [%s]: " "$def_conn"
    read -r PM_CONN; [ -z "$PM_CONN" ] && PM_CONN="$def_conn"
    PM_MODE="manual"
    printf "  NoDelay [%s]: " "$def_nodelay"
    read -r PM_NODELAY; [ -z "$PM_NODELAY" ] && PM_NODELAY="$def_nodelay"
    printf "  Interval [%s]: " "$def_interval"
    read -r PM_INTERVAL; [ -z "$PM_INTERVAL" ] && PM_INTERVAL="$def_interval"
    printf "  Resend [%s]: " "$def_resend"
    read -r PM_RESEND; [ -z "$PM_RESEND" ] && PM_RESEND="$def_resend"
    printf "  NoCongestion [%s]: " "$def_nc"
    read -r PM_NC; [ -z "$PM_NC" ] && PM_NC="$def_nc"
    printf "  WaitDelay (true/false) [%s]: " "$def_wdelay"
    read -r PM_WDELAY; [ -z "$PM_WDELAY" ] && PM_WDELAY="$def_wdelay"
    printf "  AckNoDelay (true/false) [%s]: " "$def_ack"
    read -r PM_ACK; [ -z "$PM_ACK" ] && PM_ACK="$def_ack"
    printf "  MTU [%s]: " "$def_mtu"
    read -r PM_MTU; [ -z "$PM_MTU" ] && PM_MTU="$def_mtu"
    printf "  RcvWnd [%s]: " "$def_rcvwnd"
    read -r PM_RCVWND; [ -z "$PM_RCVWND" ] && PM_RCVWND="$def_rcvwnd"
    printf "  SndWnd [%s]: " "$def_sndwnd"
    read -r PM_SNDWND; [ -z "$PM_SNDWND" ] && PM_SNDWND="$def_sndwnd"
    printf "  Block [%s]: " "$def_block"
    read -r PM_BLOCK; [ -z "$PM_BLOCK" ] && PM_BLOCK="$def_block"
    printf "  SMuxBuf [%s]: " "$def_smux"
    read -r PM_SMUX; [ -z "$PM_SMUX" ] && PM_SMUX="$def_smux"
    printf "  StreamBuf [%s]: " "$def_stream"
    read -r PM_STREAM; [ -z "$PM_STREAM" ] && PM_STREAM="$def_stream"
    printf "  DataShard [%s]: " "$def_dshard"
    read -r PM_DSHARD; [ -z "$PM_DSHARD" ] && PM_DSHARD="$def_dshard"
    printf "  ParityShard [%s]: " "$def_pshard"
    read -r PM_PSHARD; [ -z "$PM_PSHARD" ] && PM_PSHARD="$def_pshard"
}

generate_manual_kcp_block() {
    local k="$1"
    cat << TEOF
transport:
  protocol: "kcp"
  conn: $PM_CONN

  kcp:
    mode: "$PM_MODE"
    nodelay: $PM_NODELAY
    interval: $PM_INTERVAL
    resend: $PM_RESEND
    nocongestion: $PM_NC
    wdelay: $PM_WDELAY
    acknodelay: $PM_ACK
    mtu: $PM_MTU
    rcvwnd: $PM_RCVWND
    sndwnd: $PM_SNDWND
    block: "$PM_BLOCK"
    key: "$k"
    smuxbuf: $PM_SMUX
    streambuf: $PM_STREAM
    dshard: $PM_DSHARD
    pshard: $PM_PSHARD
TEOF
}

# -- Root Check --------------------------------------------------------------
if [ "$(id -u)" != "0" ]; then
    write_err "Must run as root!"
    exit 1
fi

# -- Architecture Detection --------------------------------------------------
detect_arch() {
    local arch=""
    # Try opkg first (most reliable on OpenWrt)
    if command -v opkg >/dev/null 2>&1; then
        local opkg_arch=$(opkg print-architecture 2>/dev/null | grep -oE '(x86_64|aarch64|arm_cortex|mipsel|mips|arm)' | head -n 1)
        [ -n "$opkg_arch" ] && arch="$opkg_arch"
    fi
    # Fallback to uname
    [ -z "$arch" ] && arch=$(uname -m)

    case "$arch" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        arm*|arm_cortex*) echo "arm32" ;;
        mipsel*|mips64el*) echo "mipsle" ;;
        mips64) echo "mips64" ;;
        mips)
            if [ "$(echo -n I | od -to2 2>/dev/null | awk '{print $2}' | cut -c1)" = "0" ]; then
                echo "mipsle"
            else
                echo "mips"
            fi
            ;;
        *)
            if opkg print-architecture 2>/dev/null | grep -q "mipsel"; then echo "mipsle"
            elif opkg print-architecture 2>/dev/null | grep -q "mips_"; then echo "mips"
            elif opkg print-architecture 2>/dev/null | grep -q "aarch64"; then echo "arm64"
            elif opkg print-architecture 2>/dev/null | grep -q "arm"; then echo "arm32"
            else echo "unknown"
            fi
            ;;
    esac
}

# -- Network Detection ------------------------------------------------------
get_network_info() {
    # WAN interface
    NET_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)
    [ -z "$NET_IFACE" ] && NET_IFACE="eth0"

    # Local IP
    NET_IP=$(ip -4 addr show "$NET_IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
    [ -z "$NET_IP" ] && NET_IP=$(ip -4 addr show br-lan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)

    # Gateway IP
    NET_GW=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)

    # Gateway MAC
    NET_MAC=""
    if [ -n "$NET_GW" ]; then
        NET_MAC=$(ip neigh show "$NET_GW" 2>/dev/null | grep -oE '..:..:..:..:..:..' | head -n1)
        if [ -z "$NET_MAC" ]; then
            ping -c 1 -W 2 "$NET_GW" >/dev/null 2>&1 || true
            sleep 1
            NET_MAC=$(ip neigh show "$NET_GW" 2>/dev/null | grep -oE '..:..:..:..:..:..' | head -n1)
        fi
    fi
}

# -- Dependencies ------------------------------------------------------------
install_deps() {
    write_info "Checking dependencies..."
    local deps="libpcap curl ca-bundle kmod-nft-bridge"
    local missing=""
    for dep in $deps; do
        if ! opkg list-installed 2>/dev/null | grep -q "^$dep "; then
            missing="$missing $dep"
        fi
    done

    if [ -n "$missing" ]; then
        write_info "Installing:$missing"
        opkg update >/dev/null 2>&1
        opkg install $missing 2>/dev/null
    else
        write_ok "All dependencies installed."
    fi

    # Symlinks
    [ ! -f /lib/ld-linux-aarch64.so.1 ] && ln -sf /lib/ld-musl-aarch64.so.1 /lib/ld-linux-aarch64.so.1 2>/dev/null
    [ ! -f /usr/lib/libpcap.so.1 ] && ln -sf /usr/lib/libpcap.so.1.0 /usr/lib/libpcap.so.1 2>/dev/null
}

# -- Binary Download ---------------------------------------------------------
download_binary() {
    local bin_arch=$(detect_arch)
    if [ "$bin_arch" = "unknown" ]; then
        write_err "Unsupported architecture: $(uname -m)"
        return 1
    fi
    write_info "Architecture: $bin_arch"

    write_info "Fetching latest release..."
    local response=$(curl -sL --retry 3 -A "paqx-manager" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
    local tag=$(echo "$response" | grep -o '"tag_name":[ ]*"[^"]*"' | head -n1 | sed 's/"tag_name":[ ]*"//;s/"//')

    if [ -z "$tag" ]; then
        write_err "Could not fetch version info."
        return 1
    fi
    write_info "Latest version: $tag"

    local clean_ver="${tag#v}"
    local url=""
    url=$(echo "$response" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | grep "linux" | grep "$bin_arch" | head -1 | cut -d '"' -f 4)
    [ -z "$url" ] && url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$tag/paqet-linux-$bin_arch-$clean_ver.tar.gz"

    write_info "Downloading..."
    curl -L --retry 3 -o /tmp/paqet.tar.gz "$url"
    if [ $? -ne 0 ] || [ ! -s /tmp/paqet.tar.gz ]; then
        write_err "Download failed."
        return 1
    fi

    tar -xzf /tmp/paqet.tar.gz -C /tmp
    local new_bin=$(find /tmp -maxdepth 2 -type f \( -name "paqet" -o -name "paqet_linux_*" \) ! -name "*.tar.gz" | head -n1)

    if [ -n "$new_bin" ]; then
        mkdir -p "$INSTALL_DIR"
        mv "$new_bin" "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
        rm -f /tmp/paqet.tar.gz
        write_ok "Binary installed: $tag"
        return 0
    else
        write_err "Binary not found in archive."
        rm -f /tmp/paqet.tar.gz
        return 1
    fi
}

# -- Service File Creation ---------------------------------------------------
create_service() {
    cat > "$SERVICE_FILE" << 'SVCEOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

setup_network() {
    local retry=0
    while [ $retry -lt 30 ]; do
        WAN_INT=$(ip route show default | awk '/default/ {print $5}' | head -n1)
        GW_IP=$(ip route show default | awk '/default/ {print $3}' | head -n1)

        if [ -n "$WAN_INT" ] && [ -n "$GW_IP" ]; then
            WAN_IP=$(ip -4 addr show "$WAN_INT" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
            [ -z "$WAN_IP" ] && WAN_IP=$(ip -4 addr show br-lan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
            ping -c 1 -W 1 "$GW_IP" >/dev/null 2>&1
            ROUTER_MAC=$(ip neigh show "$GW_IP" 2>/dev/null | grep -oE '..:..:..:..:..:..' | head -n1)

            if [ -n "$WAN_IP" ] && [ -n "$ROUTER_MAC" ]; then break; fi
        fi
        sleep 3
        retry=$((retry + 1))
    done

    if [ -z "$WAN_IP" ] || [ -z "$ROUTER_MAC" ]; then return 1; fi

    # Update config with detected network
    sed -i "s|interface: .*|interface: \"$WAN_INT\"|" /etc/paqet/config.yaml
    sed -i "s|router_mac: .*|router_mac: \"$ROUTER_MAC\"|" /etc/paqet/config.yaml

    # Update IP in addr field (keep :0 suffix)
    sed -i "/ipv4:/,/router_mac:/{s|addr: .*|addr: \"$WAN_IP:0\"|}" /etc/paqet/config.yaml

    # Firewall rules
    SERVER_ADDR=$(awk '/^server:/{found=1} found && /addr:/{print $2; exit}' /etc/paqet/config.yaml | tr -d '"')
    S_IP=$(echo "$SERVER_ADDR" | cut -d: -f1)
    S_PORT=$(echo "$SERVER_ADDR" | cut -d: -f2)

    nft delete table inet paqet_rules 2>/dev/null || true
    nft add table inet paqet_rules
    nft add chain inet paqet_rules prerouting '{ type filter hook prerouting priority -300 ; }'
    nft add chain inet paqet_rules output '{ type filter hook output priority -300 ; }'
    nft add chain inet paqet_rules forward '{ type filter hook forward priority -150 ; }'
    nft add rule inet paqet_rules forward tcp flags syn tcp option maxseg size set 1300

    if [ -n "$S_IP" ] && [ -n "$S_PORT" ]; then
        nft add rule inet paqet_rules prerouting ip saddr "$S_IP" tcp sport "$S_PORT" notrack
        nft add rule inet paqet_rules output ip daddr "$S_IP" tcp dport "$S_PORT" notrack
        nft add rule inet paqet_rules output ip daddr "$S_IP" tcp dport "$S_PORT" tcp flags rst drop
    fi

    return 0
}

start_service() {
    setup_network || return 1
    procd_open_instance
    procd_set_param command /usr/bin/paqet run -c /etc/paqet/config.yaml
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn 3600 5 0
    procd_close_instance
}

stop_service() {
    nft delete table inet paqet_rules 2>/dev/null || true
}
SVCEOF
    chmod +x "$SERVICE_FILE"
    "$SERVICE_FILE" enable 2>/dev/null
}

# -- Install -----------------------------------------------------------------
install_client() {
    # 1. Dependencies
    install_deps

    # 2. Binary
    if [ ! -f "$BINARY_PATH" ]; then
        download_binary || return 1
    fi

    # 3. Config
    echo ""
    echo -e "${WHITE}--- Client Configuration ---${NC}"
    printf "  Server (IP:Port): "
    read -r server_addr
    if [ -z "$server_addr" ]; then write_err "Server address required!"; return 1; fi

    printf "  Encryption Key: "
    read -r enc_key
    if [ -z "$enc_key" ]; then write_err "Key required!"; return 1; fi

    echo ""
    echo "  1) Simple (Fast mode, key only - recommended)"
    echo "  2) Automatic (Full optimized settings)"
    echo "  3) Manual (Advanced custom settings)"
    printf "  Select [1]: "
    read -r mode
    [ -z "$mode" ] && mode="1"

    [ "$mode" = "3" ] && prompt_manual_kcp

    printf "  Local SOCKS5 Port [10800]: "
    read -r local_port
    [ -z "$local_port" ] && local_port="10800"

    # 4. Network detection
    write_info "Detecting network..."
    get_network_info
    write_ok "Interface: $NET_IFACE"
    write_ok "Local IP: $NET_IP"
    write_ok "Gateway MAC: $NET_MAC"

    # 5. Generate config
    mkdir -p "$CONF_DIR"

    if [ "$mode" = "3" ]; then
        cat > "$CONF_FILE" << EOF
role: "client"

log:
  level: "info"

socks5:
  - listen: "0.0.0.0:${local_port}"
    username: ""
    password: ""

network:
  interface: "${NET_IFACE}"
  ipv4:
    addr: "${NET_IP}:0"
    router_mac: "${NET_MAC}"

  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${server_addr}"

EOF
        generate_manual_kcp_block "${enc_key}" >> "$CONF_FILE"
    elif [ "$mode" = "2" ]; then
        cat > "$CONF_FILE" << EOF
role: "client"

log:
  level: "info"

socks5:
  - listen: "0.0.0.0:${local_port}"
    username: ""
    password: ""

network:
  interface: "${NET_IFACE}"
  ipv4:
    addr: "${NET_IP}:0"
    router_mac: "${NET_MAC}"

  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${server_addr}"

transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
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
        cat > "$CONF_FILE" << EOF
role: "client"

log:
  level: "info"

socks5:
  - listen: "0.0.0.0:${local_port}"
    username: ""
    password: ""

network:
  interface: "${NET_IFACE}"
  ipv4:
    addr: "${NET_IP}:0"
    router_mac: "${NET_MAC}"

  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${server_addr}"

transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
    key: "${enc_key}"
EOF
    fi

    write_ok "Config saved: $CONF_FILE"

    # 6. Create service
    create_service
    "$SERVICE_FILE" start
    sleep 2

    echo ""
    write_ok "PaqX Client is running!"
    echo -e "  SOCKS5 Proxy: ${YELLOW}0.0.0.0:${local_port}${NC}"
    echo ""
    printf "Press Enter to continue..."
    read -r dummy
}

# -- Dashboard ---------------------------------------------------------------
show_dashboard() {
    while true; do
        # Read config
        srv_addr=""
        socks_port=""
        if [ -f "$CONF_FILE" ]; then
            local section=""
            while IFS= read -r line; do
                case "$line" in
                    server:*) section="server" ;;
                    socks5:*|network:*|transport:*|log:*|role:*) section="" ;;
                esac
                if [ "$section" = "server" ]; then
                    case "$line" in
                        *addr:*) srv_addr=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/') ;;
                    esac
                fi
                case "$line" in
                    *listen:*) socks_port=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/') ;;
                esac
            done < "$CONF_FILE"
        fi

        # Status
        is_running=false
        pgrep -f "paqet run" >/dev/null 2>&1 && is_running=true
        is_enabled=false
        [ -f "$SERVICE_FILE" ] && "$SERVICE_FILE" enabled 2>/dev/null && is_enabled=true

        status_text="Stopped"
        status_color="$RED"
        $is_running && status_text="Running" && status_color="$GREEN"
        auto_text="Disabled"
        auto_color="$RED"
        $is_enabled && auto_text="Enabled" && auto_color="$GREEN"

        clear
        echo ""
        echo -e "  ${BLUE}+===============================+${NC}"
        echo -e "  ${BLUE}|   PaqX Client  (OpenWrt)      |${NC}"
        echo -e "  ${BLUE}+===============================+${NC}"
        echo ""
        echo -e "  ${CYAN}+------------------------------------------+${NC}"
        echo -e "  ${CYAN}|${NC} Status:  ${status_color}${status_text}${NC}$(printf '%*s' $((27 - ${#status_text})) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}|${NC} Auto:    ${auto_color}${auto_text}${NC}$(printf '%*s' $((27 - ${#auto_text})) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}+------------------------------------------+${NC}"
        echo -e "  ${CYAN}|${NC} Server:  ${YELLOW}${srv_addr}${NC}$(printf '%*s' $((27 - ${#srv_addr})) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}|${NC} SOCKS5:  ${YELLOW}${socks_port}${NC}$(printf '%*s' $((27 - ${#socks_port})) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}+------------------------------------------+${NC}"
        echo ""
        echo "   1) Status"
        echo "   2) Log"
        echo "   3) Start/Stop"
        echo "   4) Restart"
        echo "   5) Disable/Enable"
        echo "   6) Settings"
        echo "   7) Update Core"
        echo "   8) Downgrade Core"
        echo "   9) Uninstall"
        echo "   0) Exit"
        echo ""
        printf "  Select: "
        read -r opt

        case "$opt" in
            1)
                # Status
                echo ""
                local pid=$(pgrep -f "paqet run" 2>/dev/null)
                if [ -n "$pid" ]; then
                    write_ok "paqet process running (PID: $pid)"
                else
                    write_warn "paqet process not found."
                fi
                echo ""
                printf "Press Enter to continue..."
                read -r dummy
                ;;
            2)
                # Log
                echo ""
                logread 2>/dev/null | grep -i paqet | tail -n 10
                echo ""
                printf "Press Enter to continue..."
                read -r dummy
                ;;
            3)
                # Start/Stop toggle
                if $is_running; then
                    "$SERVICE_FILE" stop 2>/dev/null
                    write_ok "Stopped."
                else
                    "$SERVICE_FILE" start 2>/dev/null
                    write_ok "Started."
                fi
                sleep 2
                ;;
            4)
                # Restart
                "$SERVICE_FILE" stop 2>/dev/null
                sleep 1
                "$SERVICE_FILE" start 2>/dev/null
                write_ok "Restarted."
                sleep 2
                ;;
            5)
                # Disable/Enable toggle
                if $is_enabled; then
                    "$SERVICE_FILE" disable 2>/dev/null
                    write_ok "Auto-start disabled."
                else
                    "$SERVICE_FILE" enable 2>/dev/null
                    write_ok "Auto-start enabled."
                fi
                sleep 2
                ;;
            6)
                show_settings
                ;;
            7)
                # Update Core
                write_info "Stopping service..."
                "$SERVICE_FILE" stop 2>/dev/null
                sleep 1
                download_binary
                "$SERVICE_FILE" start 2>/dev/null
                write_ok "Updated and restarted."
                sleep 2
                ;;
            8)
                # Downgrade Core
                downgrade_core
                sleep 2
                ;;
            9)
                uninstall_paqx
                return
                ;;
            0)
                exit 0
                ;;
        esac
    done
}

# -- Settings ----------------------------------------------------------------
show_settings() {
    while true; do
        echo ""
        echo -e "  ${WHITE}--- Client Settings ---${NC}"
        echo "  1) Change Server (IP:Port & Key)"
        echo "  2) Change Local SOCKS5 Port"
        echo "  3) Change Protocol Mode"
        echo "  4) View Server Info"
        echo "  5) Refresh Network"
        echo "  0) Back"
        printf "  Select: "
        read -r s_opt

        case "$s_opt" in
            1)
                printf "  New Server (IP:Port): "
                read -r new_addr
                printf "  New Encryption Key: "
                read -r new_key

                sed -i "/^server:/,/^[^ ]/{s|addr: .*|addr: \"$new_addr\"|}" "$CONF_FILE"
                sed -i "s|key: .*|key: \"$new_key\"|" "$CONF_FILE"

                write_ok "Server config updated."
                restart_service
                ;;
            2)
                printf "  New Local Port [10800]: "
                read -r new_port
                [ -z "$new_port" ] && new_port="10800"

                sed -i "s|listen: .*|listen: \"0.0.0.0:$new_port\"|" "$CONF_FILE"

                write_ok "Local port changed to $new_port."
                restart_service
                ;;
            3)
                echo ""
                echo "  1) Simple (Fast mode, key only)"
                echo "  2) Automatic (Optimized defaults)"
                echo "  3) Manual (Advanced custom settings)"
                printf "  Select: "
                read -r pm

                [ "$pm" = "3" ] && prompt_manual_kcp

                # Extract current key
                cur_key=$(grep 'key:' "$CONF_FILE" | head -n1 | sed 's/.*"\(.*\)".*/\1/')

                # Extract head (before transport)
                head_content=$(sed '/^transport:/,$d' "$CONF_FILE")

                if [ "$pm" = "3" ]; then
                    transport_content=$(generate_manual_kcp_block "$cur_key")
                elif [ "$pm" = "2" ]; then
                    transport_content=$(cat << TEOF
transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
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
    key: "$cur_key"
    smuxbuf: 4194304
    streambuf: 2097152
    dshard: 10
    pshard: 3
TEOF
)
                else
                    transport_content=$(cat << TEOF
transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "fast"
    key: "$cur_key"
TEOF
)
                fi

                printf '%s\n%s\n' "$head_content" "$transport_content" > "$CONF_FILE"
                write_ok "Protocol mode updated."
                restart_service
                ;;
            4)
                echo ""
                info_addr=""
                info_key=""
                info_socks=""
                if [ -f "$CONF_FILE" ]; then
                    local sec=""
                    while IFS= read -r ln; do
                        case "$ln" in
                            server:*) sec="server" ;;
                            socks5:*|network:*|transport:*|log:*|role:*) [ "$sec" != "server" ] || sec="" ;;
                        esac
                        if [ "$sec" = "server" ]; then
                            case "$ln" in
                                *addr:*) info_addr=$(echo "$ln" | sed 's/.*"\(.*\)".*/\1/') ;;
                            esac
                        fi
                        case "$ln" in
                            *key:*) info_key=$(echo "$ln" | sed 's/.*"\(.*\)".*/\1/') ;;
                            *listen:*) info_socks=$(echo "$ln" | sed 's/.*"\(.*\)".*/\1/') ;;
                        esac
                    done < "$CONF_FILE"
                fi
                echo -e "  ${YELLOW}--- Current Server Info ---${NC}"
                echo -e "  Server:   ${CYAN}$info_addr${NC}"
                echo -e "  Key:      ${CYAN}$info_key${NC}"
                echo -e "  SOCKS5:   ${CYAN}$info_socks${NC}"
                echo ""
                printf "  Press Enter to continue..."
                read -r dummy
                ;;
            5)
                # Refresh Network
                echo ""
                write_info "Detecting network..."
                get_network_info
                echo ""
                echo -e "  ${YELLOW}--- Detected Network ---${NC}"
                echo -e "  Interface:   ${CYAN}$NET_IFACE${NC}"
                echo -e "  Local IP:    ${CYAN}$NET_IP${NC}"
                echo -e "  Gateway MAC: ${CYAN}$NET_MAC${NC}"
                echo ""
                printf "  Apply these settings? (Y/n): "
                read -r confirm
                if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then continue; fi

                sed -i "s|interface: .*|interface: \"$NET_IFACE\"|" "$CONF_FILE"
                sed -i "s|router_mac: .*|router_mac: \"$NET_MAC\"|" "$CONF_FILE"
                sed -i "/ipv4:/,/router_mac:/{s|addr: .*|addr: \"$NET_IP:0\"|}" "$CONF_FILE"

                write_ok "Network settings updated."
                restart_service
                ;;
            0|*)
                return
                ;;
        esac
    done
}

# -- Downgrade Core ----------------------------------------------------------
downgrade_core() {
    echo ""
    write_info "Fetching available releases..."
    local response=$(curl -sL --retry 3 -A "paqx-manager" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases?per_page=10")
    local tags=$(echo "$response" | grep -o '"tag_name":[ ]*"[^"]*"' | sed 's/"tag_name":[ ]*"//;s/"//')

    if [ -z "$tags" ]; then
        write_err "Could not fetch releases."
        return 1
    fi

    echo ""
    local i=1
    for tag in $tags; do
        echo "  $i) $tag"
        i=$((i + 1))
    done
    echo "  0) Cancel"
    echo ""
    printf "  Select version: "
    read -r pick

    if [ "$pick" = "0" ] || [ -z "$pick" ]; then return; fi

    local sel_tag=$(echo "$tags" | sed -n "${pick}p")
    if [ -z "$sel_tag" ]; then write_err "Invalid selection."; return 1; fi

    local bin_arch=$(detect_arch)
    local clean_ver="${sel_tag#v}"
    local url=""
    url=$(echo "$response" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | grep "linux" | grep "$bin_arch" | head -1 | cut -d '"' -f 4)
    [ -z "$url" ] && url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$sel_tag/paqet-linux-$bin_arch-$clean_ver.tar.gz"

    write_info "Stopping service..."
    "$SERVICE_FILE" stop 2>/dev/null
    sleep 1

    write_info "Downloading $sel_tag..."
    curl -L --retry 3 -o /tmp/paqet.tar.gz "$url"
    if [ $? -ne 0 ]; then
        write_err "Download failed."
        return 1
    fi

    tar -xzf /tmp/paqet.tar.gz -C /tmp
    local new_bin=$(find /tmp -maxdepth 2 -type f \( -name "paqet" -o -name "paqet_linux_*" \) ! -name "*.tar.gz" | head -n1)

    if [ -n "$new_bin" ]; then
        mv "$new_bin" "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
        rm -f /tmp/paqet.tar.gz
        write_ok "Downgraded to $sel_tag"
        "$SERVICE_FILE" start 2>/dev/null
        write_ok "Restarted."
    else
        write_err "Binary not found in archive."
    fi
}

# -- Restart Helper ----------------------------------------------------------
restart_service() {
    write_info "Restarting service..."
    "$SERVICE_FILE" stop 2>/dev/null
    killall paqet 2>/dev/null
    sleep 1
    "$SERVICE_FILE" start 2>/dev/null
    write_ok "Restarted."
    sleep 1
}

# -- Uninstall ---------------------------------------------------------------
uninstall_paqx() {
    echo ""
    write_err "WARNING: This will COMPLETELY remove PaqX Client."
    echo ""
    echo "  This will remove:"
    echo "  - Init.d service"
    echo "  - paqet binary"
    echo "  - Configuration files"
    echo "  - Firewall rules"
    echo "  - paqx script"
    echo ""
    printf "  Are you sure? (y/N): "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then return; fi

    write_info "Stopping service..."
    "$SERVICE_FILE" stop 2>/dev/null
    "$SERVICE_FILE" disable 2>/dev/null
    killall paqet 2>/dev/null

    write_info "Removing firewall rules..."
    nft delete table inet paqet_rules 2>/dev/null

    write_info "Removing files..."
    rm -f "$SERVICE_FILE"
    rm -f "$BINARY_PATH"
    rm -rf "$CONF_DIR"
    rm -f "$SCRIPT_PATH"

    echo ""
    write_ok "PaqX Client completely uninstalled."
    sleep 3
    exit 0
}

# -- Self-Install ------------------------------------------------------------
self_install() {
    # Copy this script to /usr/bin/paqx for easy access
    local this_script="$0"
    if [ -f "$this_script" ] && [ "$this_script" != "$SCRIPT_PATH" ]; then
        cp "$this_script" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
}

# -- Entry Point -------------------------------------------------------------
if [ "$1" = "install" ]; then
    # One-liner install mode
    install_deps
    download_binary
    self_install
    write_ok "PaqX installed! Run 'paqx' to configure."
    exit 0
fi

# Self-install if not already in /usr/bin
self_install

if [ -f "$CONF_FILE" ]; then
    show_dashboard
else
    clear
    echo ""
    echo -e "  ${BLUE}+===============================+${NC}"
    echo -e "  ${BLUE}|    PaqX Client  (OpenWrt)     |${NC}"
    echo -e "  ${BLUE}|        First Setup            |${NC}"
    echo -e "  ${BLUE}+===============================+${NC}"
    echo ""
    install_client
    if [ -f "$CONF_FILE" ]; then
        show_dashboard
    fi
fi
