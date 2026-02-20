#!/bin/bash
# PaqX Client for Linux - Standalone Setup & Management
# https://github.com/bolandi-org/paqx

set -eo pipefail

# -- Constants ---------------------------------------------------------------
INSTALL_DIR="/usr/bin"
CONF_DIR="/etc/paqx"
CONF_FILE="$CONF_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/paqx.service"
BINARY_PATH="$INSTALL_DIR/paqet"
LOG_FILE="/var/log/paqx.log"
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
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv7|armhf) echo "arm32" ;;
        mips64el|mips64le) echo "mips64le" ;;
        mips64) echo "mips64" ;;
        mipsel|mipsle) echo "mipsle" ;;
        mips) echo "mips" ;;
        *)
            write_err "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# -- Package Manager Detection -----------------------------------------------
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v zypper &>/dev/null; then echo "zypper"
    elif command -v apk &>/dev/null; then echo "apk"
    else echo "unknown"
    fi
}

install_package() {
    local package="$1"
    local pkg_mgr
    pkg_mgr=$(detect_pkg_manager)

    case "$pkg_mgr" in
        apt) apt-get install -y -q "$package" 2>/dev/null ;;
        dnf) dnf install -y -q "$package" 2>/dev/null ;;
        yum) yum install -y -q "$package" 2>/dev/null ;;
        pacman) pacman -Sy --noconfirm "$package" 2>/dev/null ;;
        zypper) zypper install -y -n "$package" 2>/dev/null ;;
        apk) apk add --no-cache "$package" 2>/dev/null ;;
        *) write_warn "Unknown package manager. Please install $package manually."; return 1 ;;
    esac
}

# -- Dependencies ------------------------------------------------------------
install_deps() {
    write_info "Checking dependencies..."

    if ! command -v curl &>/dev/null; then
        install_package curl || write_warn "Could not install curl"
    fi

    if ! command -v tar &>/dev/null; then
        install_package tar || write_warn "Could not install tar"
    fi

    if ! command -v ip &>/dev/null; then
        local pkg_mgr
        pkg_mgr=$(detect_pkg_manager)
        case "$pkg_mgr" in
            apt) install_package iproute2 ;;
            dnf|yum) install_package iproute ;;
            *) install_package iproute2 ;;
        esac
    fi

    # libpcap
    if ! ldconfig -p 2>/dev/null | grep -q libpcap; then
        write_info "Installing libpcap..."
        local pkg_mgr
        pkg_mgr=$(detect_pkg_manager)
        case "$pkg_mgr" in
            apt) install_package libpcap-dev ;;
            dnf|yum) install_package libpcap-devel ;;
            pacman) install_package libpcap ;;
            zypper) install_package libpcap-devel ;;
            apk) install_package libpcap-dev ;;
            *) write_warn "Please install libpcap manually" ;;
        esac

        # Fedora/RHEL: ensure libpcap.so.1 symlink
        if [ "$(detect_pkg_manager)" = "dnf" ] || [ "$(detect_pkg_manager)" = "yum" ]; then
            if ! ldconfig -p 2>/dev/null | grep -q 'libpcap\.so\.1 '; then
                local _pcap_lib
                _pcap_lib=$(find /usr/lib64 /usr/lib /lib64 /lib -name 'libpcap.so.*' -type f 2>/dev/null | head -1)
                if [ -n "$_pcap_lib" ]; then
                    local _libdir
                    _libdir=$(dirname "$_pcap_lib")
                    [ ! -e "${_libdir}/libpcap.so.1" ] && ln -sf "$_pcap_lib" "${_libdir}/libpcap.so.1"
                    ldconfig 2>/dev/null || true
                fi
            fi
        fi
    else
        write_ok "libpcap already installed."
    fi

    write_ok "All dependencies ready."
}

# -- Network Detection -------------------------------------------------------
get_network_info() {
    # Interface via default route
    local _route_line
    _route_line=$(ip route show default 2>/dev/null | head -1)
    if [[ "$_route_line" == *" via "* ]]; then
        NET_IFACE=$(echo "$_route_line" | awk '{print $5}')
    elif [[ "$_route_line" == *" dev "* ]]; then
        # OpenVZ/direct format
        NET_IFACE=$(echo "$_route_line" | awk '{print $3}')
    fi

    # Validate interface exists
    if [ -n "$NET_IFACE" ] && ! ip link show "$NET_IFACE" &>/dev/null; then
        NET_IFACE=""
    fi

    if [ -z "$NET_IFACE" ]; then
        NET_IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '{gsub(/ /,"",$2); print $2}' | { grep -vE '^(lo|docker[0-9]|br-|veth|virbr|tun|tap|wg)' || true; } | head -1)
    fi

    # Local IP
    NET_IP=""
    if [ -n "$NET_IFACE" ]; then
        NET_IP=$( (ip -4 addr show "$NET_IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1) || true )
    fi
    if [ -z "$NET_IP" ]; then
        NET_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        [ -z "$NET_IP" ] && NET_IP=$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{gsub(/\/.*/, "", $2); print $2; exit}')
    fi

    # Gateway IP
    NET_GW=""
    if [[ "$_route_line" == *" via "* ]]; then
        NET_GW=$(echo "$_route_line" | awk '{print $3}')
    fi

    # Gateway MAC
    NET_MAC=""
    if [ -n "$NET_GW" ]; then
        NET_MAC=$(ip neigh show "$NET_GW" 2>/dev/null | awk '/lladdr/{print $5; exit}')
        if [ -z "$NET_MAC" ]; then
            ping -c 1 -W 2 "$NET_GW" &>/dev/null || true
            sleep 1
            NET_MAC=$(ip neigh show "$NET_GW" 2>/dev/null | awk '/lladdr/{print $5; exit}')
        fi
        if [ -z "$NET_MAC" ] && command -v arp &>/dev/null; then
            NET_MAC=$(arp -n "$NET_GW" 2>/dev/null | { grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' || true; } | head -1)
        fi
    fi
}

# -- Binary Download ---------------------------------------------------------
download_binary() {
    local bin_arch
    bin_arch=$(detect_arch)
    write_info "Architecture: $bin_arch"

    write_info "Fetching latest release..."
    local response
    response=$(curl -sL --retry 3 --max-time 15 -A "paqx-manager" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")
    local tag
    tag=$(echo "$response" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')

    if [ -z "$tag" ]; then
        write_err "Could not fetch version info."
        return 1
    fi
    write_info "Latest version: $tag"

    local clean_ver="${tag#v}"
    local dl_url=""
    # Try to find asset URL from API response first
    dl_url=$(echo "$response" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | grep "linux" | grep "$bin_arch" | head -1 | cut -d '"' -f 4)
    if [ -z "$dl_url" ]; then
        dl_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$tag/paqet-linux-$bin_arch-$clean_ver.tar.gz"
    fi

    write_info "Downloading from: $dl_url"
    local tmp_file
    tmp_file=$(mktemp "/tmp/paqet-download-XXXXXXXX.tar.gz")

    local download_ok=false
    if curl -sL --max-time 180 --retry 3 --retry-delay 5 --fail -o "$tmp_file" "$dl_url" ; then
        download_ok=true
    elif command -v wget &>/dev/null; then
        write_info "curl failed, trying wget..."
        rm -f "$tmp_file"
        if wget -q --timeout=180 --tries=3 -O "$tmp_file" "$dl_url" ; then
            download_ok=true
        fi
    fi

    if [ "$download_ok" != "true" ]; then
        write_err "Download failed."
        rm -f "$tmp_file"
        return 1
    fi

    # Validate download size
    local fsize
    fsize=$(stat -c%s "$tmp_file" 2>/dev/null || wc -c < "$tmp_file" 2>/dev/null || echo 0)
    if [ "$fsize" -lt 1000 ]; then
        write_err "Downloaded file too small ($fsize bytes). Download may have failed."
        rm -f "$tmp_file"
        return 1
    fi

    local tmp_extract
    tmp_extract=$(mktemp -d "/tmp/paqet-extract-XXXXXXXX")
    tar -xzf "$tmp_file" -C "$tmp_extract" 
    if [ $? -ne 0 ]; then
        write_err "Failed to extract archive."
        rm -f "$tmp_file"
        rm -rf "$tmp_extract"
        return 1
    fi

    # Find binary
    local new_bin
    new_bin=$(find "$tmp_extract" -maxdepth 2 -type f \( -name "paqet" -o -name "paqet_linux_*" \) ! -name "*.tar.gz" | head -n1)
    if [ -z "$new_bin" ]; then
        new_bin=$(find "$tmp_extract" -name "paqet*" -type f -executable 2>/dev/null | head -1)
    fi
    if [ -z "$new_bin" ]; then
        new_bin=$(find "$tmp_extract" -name "paqet*" -type f 2>/dev/null | head -1)
    fi

    if [ -n "$new_bin" ]; then
        mkdir -p "$INSTALL_DIR"
        # Stop if running to avoid "Text file busy"
        if pgrep -f "paqet run" &>/dev/null; then
            write_info "Stopping paqet to update binary..."
            pkill -f "paqet run" 2>/dev/null || true
            sleep 1
        fi
        cp "$new_bin" "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
        rm -f "$tmp_file"
        rm -rf "$tmp_extract"
        write_ok "Binary installed: $tag"
        return 0
    else
        write_err "Binary not found in archive."
        rm -f "$tmp_file"
        rm -rf "$tmp_extract"
        return 1
    fi
}

# -- Firewall Rules ----------------------------------------------------------
apply_firewall_rules() {
    local server_addr="$1"
    [ -z "$server_addr" ] && return 0

    local s_ip="${server_addr%:*}"
    local s_port="${server_addr##*:}"
    [ -z "$s_ip" ] || [ -z "$s_port" ] && return 0

    write_info "Applying firewall rules..."

    # Load kernel modules
    modprobe iptable_raw 2>/dev/null || true
    modprobe iptable_mangle 2>/dev/null || true

    local TAG="paqx"

    # NOTRACK rules for client -> server traffic
    iptables -t raw -C PREROUTING -s "$s_ip" -p tcp --sport "$s_port" -m comment --comment "$TAG" -j NOTRACK 2>/dev/null || \
    iptables -t raw -A PREROUTING -s "$s_ip" -p tcp --sport "$s_port" -m comment --comment "$TAG" -j NOTRACK 2>/dev/null || true

    iptables -t raw -C OUTPUT -d "$s_ip" -p tcp --dport "$s_port" -m comment --comment "$TAG" -j NOTRACK 2>/dev/null || \
    iptables -t raw -A OUTPUT -d "$s_ip" -p tcp --dport "$s_port" -m comment --comment "$TAG" -j NOTRACK 2>/dev/null || true

    # Drop RST packets to server
    iptables -t mangle -C OUTPUT -d "$s_ip" -p tcp --dport "$s_port" --tcp-flags RST RST -m comment --comment "$TAG" -j DROP 2>/dev/null || \
    iptables -t mangle -A OUTPUT -d "$s_ip" -p tcp --dport "$s_port" --tcp-flags RST RST -m comment --comment "$TAG" -j DROP 2>/dev/null || true

    # IPv6 (best effort)
    if command -v ip6tables &>/dev/null; then
        ip6tables -t raw -A PREROUTING -p tcp --sport "$s_port" -m comment --comment "$TAG" -j NOTRACK 2>/dev/null || true
        ip6tables -t raw -A OUTPUT -p tcp --dport "$s_port" -m comment --comment "$TAG" -j NOTRACK 2>/dev/null || true
        ip6tables -t mangle -A OUTPUT -p tcp --dport "$s_port" --tcp-flags RST RST -m comment --comment "$TAG" -j DROP 2>/dev/null || true
    fi

    # Persist rules
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save 2>/dev/null || true
    elif command -v iptables-save &>/dev/null; then
        if [ -d /etc/iptables ]; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            command -v ip6tables-save &>/dev/null && ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true
        elif [ -d /etc/sysconfig ]; then
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
        fi
    fi

    write_ok "Firewall rules applied."
}

remove_firewall_rules() {
    local TAG="paqx"

    # Remove all rules tagged with paqx
    while iptables -t raw -D PREROUTING -m comment --comment "$TAG" -j NOTRACK 2>/dev/null; do :; done
    while iptables -t raw -D OUTPUT -m comment --comment "$TAG" -j NOTRACK 2>/dev/null; do :; done
    while iptables -t mangle -D OUTPUT -m comment --comment "$TAG" -j DROP 2>/dev/null; do :; done

    if command -v ip6tables &>/dev/null; then
        while ip6tables -t raw -D PREROUTING -m comment --comment "$TAG" -j NOTRACK 2>/dev/null; do :; done
        while ip6tables -t raw -D OUTPUT -m comment --comment "$TAG" -j NOTRACK 2>/dev/null; do :; done
        while ip6tables -t mangle -D OUTPUT -m comment --comment "$TAG" -j DROP 2>/dev/null; do :; done
    fi
}

# -- Install -----------------------------------------------------------------
install_client() {
    # 1. Dependencies
    install_deps

    # 2. Binary
    if [ ! -f "$BINARY_PATH" ]; then
        download_binary || return 1
    fi

    # 3. Client config
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
  - listen: "127.0.0.1:${local_port}"
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
  - listen: "127.0.0.1:${local_port}"
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
    mode: "manual"
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
  - listen: "127.0.0.1:${local_port}"
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

    chmod 600 "$CONF_FILE"
    write_ok "Config saved: $CONF_FILE"

    # 6. Firewall rules
    apply_firewall_rules "$server_addr"

    # 7. Create systemd service
    write_info "Creating systemd service..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=PaqX Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BINARY_PATH run -c $CONF_FILE
Restart=on-failure
RestartSec=5
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal
SyslogIdentifier=paqx

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable paqx 2>/dev/null
    systemctl start paqx
    sleep 2

    echo ""
    write_ok "PaqX Client is running!"
    echo -e "  SOCKS5 Proxy: ${YELLOW}127.0.0.1:${local_port}${NC}"
    echo ""
    printf "Press Enter to continue..."
    read -r dummy
}

# -- Dashboard ---------------------------------------------------------------
show_dashboard() {
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
                        *addr:*) srv_addr=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/') ;;
                    esac
                fi
                case "$line" in
                    *listen:*) socks_port=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/') ;;
                esac
            done < "$CONF_FILE"
        fi

        # Status
        local is_running=false
        systemctl is-active --quiet paqx 2>/dev/null && is_running=true
        local is_enabled
        is_enabled=$(systemctl is-enabled paqx 2>/dev/null)

        local status_text="Stopped"
        local status_color="$RED"
        $is_running && status_text="Running" && status_color="$GREEN"
        local auto_text="Disabled"
        local auto_color="$RED"
        [ "$is_enabled" = "enabled" ] && auto_text="Enabled" && auto_color="$GREEN"

        local max_len=${#srv_addr}
        [ ${#socks_port} -gt $max_len ] && max_len=${#socks_port}
        [ 12 -gt $max_len ] && max_len=12
        local card_w=$((max_len + 16))
        [ $card_w -lt 42 ] && card_w=42
        local border=$(printf '%0.s-' $(seq 1 $card_w))

        clear
        echo ""
        echo -e "  ${BLUE}+===============================+${NC}"
        echo -e "  ${BLUE}|     PaqX Client  (Linux)      |${NC}"
        echo -e "  ${BLUE}+===============================+${NC}"
        echo ""
        echo -e "  ${CYAN}+${border}+${NC}"
        echo -e "  ${CYAN}|${NC} Status:  ${status_color}${status_text}${NC}$(printf '%*s' $((card_w - ${#status_text} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}|${NC} Auto:    ${auto_color}${auto_text}${NC}$(printf '%*s' $((card_w - ${#auto_text} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}+${border}+${NC}"
        echo -e "  ${CYAN}|${NC} Server:  ${YELLOW}${srv_addr}${NC}$(printf '%*s' $((card_w - ${#srv_addr} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}|${NC} SOCKS5:  ${YELLOW}${socks_port}${NC}$(printf '%*s' $((card_w - ${#socks_port} - 11)) '')${CYAN}|${NC}"
        echo -e "  ${CYAN}+${border}+${NC}"
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
                local pid
                pid=$(pgrep -f "paqet run" 2>/dev/null)
                if [ -n "$pid" ]; then
                    write_ok "paqet process running (PID: $pid)"
                else
                    write_warn "paqet process not found."
                fi
                echo ""
                systemctl status paqx --no-pager 2>/dev/null || true
                echo ""
                printf "Press Enter to continue..."
                read -r dummy
                ;;
            2)
                # Log
                echo ""
                journalctl -u paqx -n 30 --no-pager 2>/dev/null || write_warn "No journal logs found."
                echo ""
                printf "Press Enter to continue..."
                read -r dummy
                ;;
            3)
                # Start/Stop toggle
                if $is_running; then
                    systemctl stop paqx 2>/dev/null
                    pkill -f "paqet run" 2>/dev/null || true
                    write_ok "Stopped."
                else
                    systemctl start paqx 2>/dev/null
                    write_ok "Started."
                fi
                sleep 2
                ;;
            4)
                # Restart
                systemctl stop paqx 2>/dev/null
                pkill -f "paqet run" 2>/dev/null || true
                sleep 1
                systemctl start paqx 2>/dev/null
                write_ok "Restarted."
                sleep 2
                ;;
            5)
                # Disable/Enable toggle
                if [ "$is_enabled" = "enabled" ]; then
                    systemctl disable paqx 2>/dev/null
                    write_ok "Auto-start disabled."
                else
                    systemctl enable paqx 2>/dev/null
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
                systemctl stop paqx 2>/dev/null
                pkill -f "paqet run" 2>/dev/null || true
                sleep 1
                if download_binary; then
                    systemctl start paqx 2>/dev/null
                    write_ok "Updated and restarted."
                fi
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

                # Remove old firewall rules
                local old_addr
                old_addr=$(awk '/^server:/{found=1} found && /addr:/{print $2; exit}' "$CONF_FILE" | tr -d '"')
                [ -n "$old_addr" ] && remove_firewall_rules

                sed -i "/^server:/,/^[^ ]/{s|addr: .*|addr: \"$new_addr\"|}" "$CONF_FILE"
                sed -i "s|key: .*|key: \"$new_key\"|" "$CONF_FILE"

                # Apply new firewall rules
                apply_firewall_rules "$new_addr"

                write_ok "Server config updated."
                restart_service
                ;;
            2)
                printf "  New Local Port [10800]: "
                read -r new_port
                [ -z "$new_port" ] && new_port="10800"

                sed -i "s|listen: .*|listen: \"127.0.0.1:$new_port\"|" "$CONF_FILE"

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
                local cur_key
                cur_key=$(grep 'key:' "$CONF_FILE" | head -n1 | sed 's/.*"\(.*\)".*/\1/')

                # Extract head (before transport)
                local head_content
                head_content=$(sed '/^transport:/,$d' "$CONF_FILE")

                if [ "$pm" = "3" ]; then
                    local transport_content
                    transport_content=$(generate_manual_kcp_block "$cur_key")
                elif [ "$pm" = "2" ]; then
                    local transport_content
                    transport_content=$(cat << TEOF
transport:
  protocol: "kcp"
  conn: 1

  kcp:
    mode: "manual"
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
                    local transport_content
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
                chmod 600 "$CONF_FILE"
                write_ok "Protocol mode updated."
                restart_service
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
    local response
    response=$(curl -sL --retry 3 --max-time 15 -A "paqx-manager" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases?per_page=10")
    local tags
    tags=$(echo "$response" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"tag_name"[[:space:]]*:[[:space:]]*"//;s/"//')

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

    local sel_tag
    sel_tag=$(echo "$tags" | sed -n "${pick}p")
    if [ -z "$sel_tag" ]; then write_err "Invalid selection."; return 1; fi

    local bin_arch
    bin_arch=$(detect_arch)
    local clean_ver="${sel_tag#v}"

    # Try to find asset URL
    local sel_response
    sel_response=$(curl -sL --retry 3 -A "paqx-manager" "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$sel_tag")
    local dl_url
    dl_url=$(echo "$sel_response" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | grep "linux" | grep "$bin_arch" | head -1 | cut -d '"' -f 4)
    [ -z "$dl_url" ] && dl_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$sel_tag/paqet-linux-$bin_arch-$clean_ver.tar.gz"

    write_info "Stopping service..."
    systemctl stop paqx 2>/dev/null
    pkill -f "paqet run" 2>/dev/null || true
    sleep 1

    write_info "Downloading $sel_tag..."
    local tmp_file
    tmp_file=$(mktemp "/tmp/paqet-download-XXXXXXXX.tar.gz")
    curl -sL --max-time 180 --retry 3 --fail -o "$tmp_file" "$dl_url"
    if [ $? -ne 0 ]; then
        write_err "Download failed."
        rm -f "$tmp_file"
        return 1
    fi

    local tmp_extract
    tmp_extract=$(mktemp -d "/tmp/paqet-extract-XXXXXXXX")
    tar -xzf "$tmp_file" -C "$tmp_extract"
    local new_bin
    new_bin=$(find "$tmp_extract" -maxdepth 2 -type f \( -name "paqet" -o -name "paqet_linux_*" \) ! -name "*.tar.gz" | head -n1)
    [ -z "$new_bin" ] && new_bin=$(find "$tmp_extract" -name "paqet*" -type f 2>/dev/null | head -1)

    if [ -n "$new_bin" ]; then
        cp "$new_bin" "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
        rm -f "$tmp_file"
        rm -rf "$tmp_extract"
        write_ok "Downgraded to $sel_tag"
        systemctl start paqx 2>/dev/null
        write_ok "Restarted."
    else
        write_err "Binary not found in archive."
        rm -f "$tmp_file"
        rm -rf "$tmp_extract"
    fi
}

# -- Restart Helper ----------------------------------------------------------
restart_service() {
    write_info "Restarting service..."
    systemctl stop paqx 2>/dev/null
    pkill -f "paqet run" 2>/dev/null || true
    sleep 1
    systemctl start paqx 2>/dev/null
    write_ok "Restarted."
    sleep 1
}

# -- Uninstall ---------------------------------------------------------------
uninstall_paqx() {
    echo ""
    write_err "WARNING: This will COMPLETELY remove PaqX Client."
    echo ""
    echo "  This will remove:"
    echo "  - Systemd service (paqx)"
    echo "  - paqet binary"
    echo "  - Configuration files"
    echo "  - Firewall rules"
    echo "  - paqx script"
    echo ""
    printf "  Are you sure? (y/N): "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then return; fi

    write_info "Stopping service..."
    systemctl stop paqx 2>/dev/null || true
    systemctl disable paqx 2>/dev/null || true
    pkill -f "paqet run" 2>/dev/null || true

    write_info "Removing firewall rules..."
    remove_firewall_rules

    write_info "Removing files..."
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload 2>/dev/null || true
    rm -f "$BINARY_PATH"
    rm -rf "$CONF_DIR"
    rm -f "$SCRIPT_PATH"
    rm -f /usr/local/bin/paqx 2>/dev/null

    echo ""
    write_ok "PaqX Client completely uninstalled."
    sleep 3
    exit 0
}

# -- Self-Install ------------------------------------------------------------
self_install() {
    local this_script="$0"
    if [ -f "$this_script" ] && [ "$this_script" != "$SCRIPT_PATH" ]; then
        cp "$this_script" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
}

# -- Entry Point -------------------------------------------------------------
if [ "$1" = "install" ]; then
    install_deps
    download_binary
    self_install
    write_ok "PaqX installed! Run 'paqx' to configure."
    exit 0
fi

self_install

if [ -f "$CONF_FILE" ] && grep -q 'role: "client"' "$CONF_FILE"; then
    show_dashboard
else
    clear
    echo ""
    echo -e "  ${BLUE}+===============================+${NC}"
    echo -e "  ${BLUE}|     PaqX Client  (Linux)      |${NC}"
    echo -e "  ${BLUE}+===============================+${NC}"
    echo ""
    echo -e "  1) Install Client"
    echo -e "  0) Exit"
    echo ""
    printf "  Select: "
    read -r choice
    if [ "$choice" = "1" ]; then
        install_client
        show_dashboard
    else
        exit 0
    fi
fi
