#!/bin/bash

source "$LIB_DIR/core.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/crypto.sh"

optimize_kernel() {
    log_info "Optimizing Kernel Parameters..."
    
    if ! grep -q "tcp_bbr" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.conf
    fi
    
    cat >> /etc/sysctl.conf <<EOF
fs.file-max = 1000000
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
EOF
    
    sysctl -p >/dev/null 2>&1
    log_success "Kernel optimized."
}

calculate_config() {
    local total_mem
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local cpu_cores
    cpu_cores=$(nproc)
    
    log_info "System: ${total_mem}MB RAM, ${cpu_cores} Cores"
    
    CONF_SNDWND=1024; CONF_RCVWND=1024; CONF_CONN=1; CONF_SOCKBUF=4194304
    
    if [ "$total_mem" -gt 4000 ]; then
        CONF_SNDWND=4096; CONF_RCVWND=4096; CONF_SOCKBUF=16777216
    elif [ "$total_mem" -gt 1000 ]; then
        CONF_SNDWND=2048; CONF_RCVWND=2048; CONF_SOCKBUF=8388608
    fi
    
    if [ "$cpu_cores" -ge 4 ]; then CONF_CONN=4
    elif [ "$cpu_cores" -ge 2 ]; then CONF_CONN=2; fi
}

apply_firewall() {
    local port="$1"
    log_info "Applying Firewall Rules (Anti-Probing)..."
    
    if command -v firewall-cmd >/dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --direct --add-rule ipv4 raw PREROUTING 0 -p tcp --dport "$port" -j NOTRACK >/dev/null 2>&1
            firewall-cmd --direct --add-rule ipv4 raw OUTPUT 0 -p tcp --sport "$port" -j NOTRACK >/dev/null 2>&1
            firewall-cmd --direct --add-rule ipv4 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -j DROP >/dev/null 2>&1
            log_success "Firewalld rules applied."
            return
        fi
    fi
    
    iptables -t raw -I PREROUTING -p tcp --dport "$port" -j NOTRACK >/dev/null 2>&1
    iptables -t raw -I OUTPUT -p tcp --sport "$port" -j NOTRACK >/dev/null 2>&1
    iptables -t mangle -I OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP >/dev/null 2>&1
    log_success "IPTables rules applied."
}

# --- FIRST RUN: Pre-install prompts ---

SRV_PORT=""
SRV_KEY=""

server_pre_install() {
    echo -e "\n${BOLD}--- Server Installation ---${NC}"
    
    # Step 1: Port
    read -p "Listen Port [8443]: " SRV_PORT
    SRV_PORT=${SRV_PORT:-8443}
    
    # Step 2: Protocol mode
    echo ""
    echo "1) Automatic (Recommended - based on server specs)"
    echo "2) Manual (Configure all protocol values)"
    read -p "Select [1]: " p_mode
    p_mode=${p_mode:-1}
    
    if [ "$p_mode" = "2" ]; then
        echo -e "\n${YELLOW}--- Protocol Settings ---${NC}"
        echo "Enter values (press Enter for default):"

        read -p "nodelay [1]: " P_NODELAY; P_NODELAY=${P_NODELAY:-1}
        read -p "interval [10]: " P_INTERVAL; P_INTERVAL=${P_INTERVAL:-10}
        read -p "resend [2]: " P_RESEND; P_RESEND=${P_RESEND:-2}
        read -p "nocongestion [1]: " P_NOCONG; P_NOCONG=${P_NOCONG:-1}
        read -p "wdelay [false]: " P_WDELAY; P_WDELAY=${P_WDELAY:-false}
        read -p "acknodelay [true]: " P_ACKNO; P_ACKNO=${P_ACKNO:-true}
        read -p "mtu [1350]: " P_MTU; P_MTU=${P_MTU:-1350}
        read -p "rcvwnd [1024]: " P_RCVWND; P_RCVWND=${P_RCVWND:-1024}
        read -p "sndwnd [1024]: " P_SNDWND; P_SNDWND=${P_SNDWND:-1024}
        read -p "block [aes]: " P_BLOCK; P_BLOCK=${P_BLOCK:-aes}
        read -p "smuxbuf [4194304]: " P_SMUXBUF; P_SMUXBUF=${P_SMUXBUF:-4194304}
        read -p "streambuf [2097152]: " P_STREAMBUF; P_STREAMBUF=${P_STREAMBUF:-2097152}
        read -p "dshard [10]: " P_DSHARD; P_DSHARD=${P_DSHARD:-10}
        read -p "pshard [3]: " P_PSHARD; P_PSHARD=${P_PSHARD:-3}
        SRV_MANUAL=1
    else
        SRV_MANUAL=0
    fi
}

# --- FIRST RUN: Install server ---

install_server() {
    if [ -z "$SRV_PORT" ]; then server_pre_install; fi
    
    optimize_kernel
    IFACE=$(scan_interface)
    SRV_KEY=$(generate_key)
    
    # Detect local IP on the interface
    LOCAL_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)
    [ -z "$LOCAL_IP" ] && LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    # Detect gateway MAC
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
    
    if [ "$SRV_MANUAL" = "1" ]; then
        CONF_RCVWND=$P_RCVWND
        CONF_SNDWND=$P_SNDWND
        CONF_SOCKBUF=4194304
    else
        calculate_config
        P_NODELAY=1; P_INTERVAL=10; P_RESEND=2; P_NOCONG=1
        P_WDELAY=false; P_ACKNO=true; P_MTU=1350
        P_RCVWND=$CONF_RCVWND; P_SNDWND=$CONF_SNDWND
        P_BLOCK=aes; P_SMUXBUF=4194304; P_STREAMBUF=2097152; P_DSHARD=10; P_PSHARD=3
    fi
    
    mkdir -p "$CONF_DIR"
    cat > "$CONF_FILE" <<EOF
role: "server"

log:
  level: "info"

listen:
  addr: ":${SRV_PORT}"

network:
  interface: "${IFACE}"
  ipv4:
    addr: "${LOCAL_IP}:${SRV_PORT}"
    router_mac: "${GW_MAC}"

transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    nodelay: $P_NODELAY
    interval: $P_INTERVAL
    resend: $P_RESEND
    nocongestion: $P_NOCONG
    wdelay: $P_WDELAY
    acknodelay: $P_ACKNO
    mtu: $P_MTU
    rcvwnd: $P_RCVWND
    sndwnd: $P_SNDWND
    block: "$P_BLOCK"
    key: "${SRV_KEY}"
    smuxbuf: $P_SMUXBUF
    streambuf: $P_STREAMBUF
    dshard: $P_DSHARD
    pshard: $P_PSHARD
EOF

    cat > "$SERVICE_FILE_LINUX" <<EOF
[Unit]
Description=PaqX Server
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH run -c $CONF_FILE
Restart=always
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable paqx
    systemctl start paqx
    
    apply_firewall "$SRV_PORT"
    
    PUB_IP=$(get_public_ip)
    
    local addr_str="${PUB_IP}:${SRV_PORT}"
    local key_str="${SRV_KEY}"
    # Dynamic card width
    local max_len=${#addr_str}
    [ ${#key_str} -gt $max_len ] && max_len=${#key_str}
    local card_w=$((max_len + 14))
    local border=$(printf '─%.0s' $(seq 1 $card_w))
    
    echo -e "\n${GREEN}${BOLD}Server Installed!${NC}"
    echo -e "${CYAN}┌${border}┐${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}Address:${NC}  ${YELLOW}${addr_str}${NC}$(printf '%*s' $((card_w - ${#addr_str} - 11)) '')${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}Key:${NC}      ${YELLOW}${key_str}${NC}$(printf '%*s' $((card_w - ${#key_str} - 11)) '')${CYAN}│${NC}"
    echo -e "${CYAN}└${border}┘${NC}"
}

# --- SECOND RUN: Settings submenu ---

configure_server() {
    while true; do
        echo -e "\n${BOLD}--- Server Settings ---${NC}"
        echo "1) Change Port"
        echo "2) Regenerate Encrypted Key"
        echo "3) Change Protocol Setting"
        echo "0) Back"
        read -p "Select: " s_opt
        
        case $s_opt in
            1)
                read -p "New Port: " NEW_PORT
                OLD_PORT=$(grep "addr: \":" "$CONF_FILE" | head -1 | cut -d ':' -f 3 | tr -d '"')
                
                sed -i "s/addr: \":$OLD_PORT\"/addr: \":$NEW_PORT\"/" "$CONF_FILE"
                sed -i "s/addr: \"0.0.0.0:$OLD_PORT\"/addr: \"0.0.0.0:$NEW_PORT\"/" "$CONF_FILE"
                
                apply_firewall "$NEW_PORT"
                log_success "Port changed to $NEW_PORT"
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            2)
                NEW_KEY=$(generate_key)
                sed -i "s/key: .*/key: \"$NEW_KEY\"/" "$CONF_FILE"
                log_success "New Key: $NEW_KEY"
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            3)
                echo -e "\n${YELLOW}--- Protocol Settings ---${NC}"
                echo "Current values (leave blank to keep):"
                

                read -p "nodelay [1]: " val; [ -n "$val" ] && sed -i "s/nodelay: .*/nodelay: $val/" "$CONF_FILE"
                read -p "interval [10]: " val; [ -n "$val" ] && sed -i "s/interval: .*/interval: $val/" "$CONF_FILE"
                read -p "resend [2]: " val; [ -n "$val" ] && sed -i "s/resend: .*/resend: $val/" "$CONF_FILE"
                read -p "nocongestion [1]: " val; [ -n "$val" ] && sed -i "s/nocongestion: .*/nocongestion: $val/" "$CONF_FILE"
                read -p "wdelay [false]: " val; [ -n "$val" ] && sed -i "s/wdelay: .*/wdelay: $val/" "$CONF_FILE"
                read -p "acknodelay [true]: " val; [ -n "$val" ] && sed -i "s/acknodelay: .*/acknodelay: $val/" "$CONF_FILE"
                read -p "mtu [1350]: " val; [ -n "$val" ] && sed -i "s/mtu: .*/mtu: $val/" "$CONF_FILE"
                read -p "rcvwnd [1024]: " val; [ -n "$val" ] && sed -i "s/rcvwnd: .*/rcvwnd: $val/" "$CONF_FILE"
                read -p "sndwnd [1024]: " val; [ -n "$val" ] && sed -i "s/sndwnd: .*/sndwnd: $val/" "$CONF_FILE"
                read -p "block [aes]: " val; [ -n "$val" ] && sed -i "s/block: .*/block: \"$val\"/" "$CONF_FILE"
                read -p "smuxbuf [4194304]: " val; [ -n "$val" ] && sed -i "s/smuxbuf: .*/smuxbuf: $val/" "$CONF_FILE"
                read -p "streambuf [2097152]: " val; [ -n "$val" ] && sed -i "s/streambuf: .*/streambuf: $val/" "$CONF_FILE"
                read -p "dshard [10]: " val; [ -n "$val" ] && sed -i "s/dshard: .*/dshard: $val/" "$CONF_FILE"
                read -p "pshard [3]: " val; [ -n "$val" ] && sed -i "s/pshard: .*/pshard: $val/" "$CONF_FILE"
                
                log_success "Protocol settings updated."
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            0|*) return ;;
        esac
    done
}

# --- Uninstall ---

remove_server() {
    echo -e "${RED}${BOLD}WARNING: This will remove PaqX Server completely.${NC}"
    read -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then return; fi
    
    log_info "Stopping service..."
    systemctl stop paqx
    systemctl disable paqx
    rm -f "$SERVICE_FILE_LINUX"
    systemctl daemon-reload
    
    log_info "Removing files..."
    rm -f "$BINARY_PATH"
    rm -rf "$CONF_DIR"
    rm -rf "$PAQX_ROOT"
    rm -f "/usr/bin/paqx"
    
    log_success "PaqX Server uninstalled."
}
