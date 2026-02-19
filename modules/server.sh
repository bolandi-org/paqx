#!/bin/bash

source "$LIB_DIR/core.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/crypto.sh"

optimize_kernel() {
    log_info "Optimizing Kernel Parameters..."
    
    # Use separate file - NEVER modify /etc/sysctl.conf directly
    cat > /etc/sysctl.d/99-paqx.conf <<EOF
# PaqX kernel optimizations - safe to remove
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
fs.file-max=1000000
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.core.rmem_default=16777216
net.core.wmem_default=16777216
EOF
    
    sysctl --system >/dev/null 2>&1
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

PAQX_FW_TAG="paqx"

apply_firewall() {
    local port="$1"
    log_info "Applying Firewall Rules (Anti-Probing)..."
    
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        # firewalld with comment tags
        firewall-cmd --direct --query-rule ipv4 raw PREROUTING 0 -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
            firewall-cmd --direct --add-rule ipv4 raw PREROUTING 0 -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --query-rule ipv4 raw OUTPUT 0 -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
            firewall-cmd --direct --add-rule ipv4 raw OUTPUT 0 -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --query-rule ipv4 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -m comment --comment "$PAQX_FW_TAG" -j DROP 2>/dev/null || \
            firewall-cmd --direct --add-rule ipv4 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -m comment --comment "$PAQX_FW_TAG" -j DROP 2>/dev/null || true
        # IPv6
        firewall-cmd --direct --query-rule ipv6 raw PREROUTING 0 -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
            firewall-cmd --direct --add-rule ipv6 raw PREROUTING 0 -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --query-rule ipv6 raw OUTPUT 0 -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
            firewall-cmd --direct --add-rule ipv6 raw OUTPUT 0 -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --query-rule ipv6 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -m comment --comment "$PAQX_FW_TAG" -j DROP 2>/dev/null || \
            firewall-cmd --direct --add-rule ipv6 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -m comment --comment "$PAQX_FW_TAG" -j DROP 2>/dev/null || true
        log_success "Firewalld rules applied."
        return
    fi
    
    # iptables with comment tags - check before adding (idempotent)
    modprobe iptable_raw 2>/dev/null || true
    modprobe iptable_mangle 2>/dev/null || true
    
    iptables -t raw -C PREROUTING -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
        iptables -t raw -A PREROUTING -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
    iptables -t raw -C OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
        iptables -t raw -A OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
    iptables -t mangle -C OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" --tcp-flags RST RST -j DROP 2>/dev/null || \
        iptables -t mangle -A OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" --tcp-flags RST RST -j DROP 2>/dev/null || true
    
    # IPv6
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -t raw -C PREROUTING -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
            ip6tables -t raw -A PREROUTING -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        ip6tables -t raw -C OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || \
            ip6tables -t raw -A OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        ip6tables -t mangle -C OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" --tcp-flags RST RST -j DROP 2>/dev/null || \
            ip6tables -t mangle -A OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" --tcp-flags RST RST -j DROP 2>/dev/null || true
    fi
    
    log_success "IPTables rules applied."
}

remove_firewall() {
    local port="$1"
    log_info "Removing firewall rules for port $port..."
    
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --direct --remove-rule ipv4 raw PREROUTING 0 -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --remove-rule ipv4 raw OUTPUT 0 -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --remove-rule ipv4 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -m comment --comment "$PAQX_FW_TAG" -j DROP 2>/dev/null || true
        firewall-cmd --permanent --direct --remove-rule ipv4 raw PREROUTING 0 -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --permanent --direct --remove-rule ipv4 raw OUTPUT 0 -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --permanent --direct --remove-rule ipv4 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -m comment --comment "$PAQX_FW_TAG" -j DROP 2>/dev/null || true
        # IPv6
        firewall-cmd --direct --remove-rule ipv6 raw PREROUTING 0 -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --remove-rule ipv6 raw OUTPUT 0 -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        firewall-cmd --direct --remove-rule ipv6 mangle OUTPUT 0 -p tcp --sport "$port" --tcp-flags RST RST -m comment --comment "$PAQX_FW_TAG" -j DROP 2>/dev/null || true
        log_success "Firewalld rules removed."
        return
    fi
    
    if command -v iptables >/dev/null 2>&1; then
        # Remove tagged rules
        iptables -t raw -D PREROUTING -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        iptables -t raw -D OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        iptables -t mangle -D OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" --tcp-flags RST RST -j DROP 2>/dev/null || true
        # Also remove legacy untagged rules (from old versions)
        iptables -t raw -D PREROUTING -p tcp --dport "$port" -j NOTRACK 2>/dev/null || true
        iptables -t raw -D OUTPUT -p tcp --sport "$port" -j NOTRACK 2>/dev/null || true
        iptables -t mangle -D OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP 2>/dev/null || true
        log_success "IPTables rules removed."
    fi
    
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -t raw -D PREROUTING -p tcp --dport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        ip6tables -t raw -D OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" -j NOTRACK 2>/dev/null || true
        ip6tables -t mangle -D OUTPUT -p tcp --sport "$port" -m comment --comment "$PAQX_FW_TAG" --tcp-flags RST RST -j DROP 2>/dev/null || true
        ip6tables -t raw -D PREROUTING -p tcp --dport "$port" -j NOTRACK 2>/dev/null || true
        ip6tables -t raw -D OUTPUT -p tcp --sport "$port" -j NOTRACK 2>/dev/null || true
        ip6tables -t mangle -D OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP 2>/dev/null || true
    fi
}

remove_all_paqx_firewall_rules() {
    log_info "Removing ALL paqx firewall rules..."
    
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        local rules
        rules=$(firewall-cmd --direct --get-all-rules 2>/dev/null) || true
        if [ -n "$rules" ]; then
            echo "$rules" | grep "$PAQX_FW_TAG" | while IFS= read -r rule; do
                firewall-cmd --direct --remove-rule $rule 2>/dev/null || true
                firewall-cmd --permanent --direct --remove-rule $rule 2>/dev/null || true
            done
        fi
        return
    fi
    
    if command -v iptables >/dev/null 2>&1; then
        local i
        for i in {1..10}; do
            iptables -t raw -S 2>/dev/null | grep -q "$PAQX_FW_TAG" || break
            iptables -t raw -S 2>/dev/null | grep "$PAQX_FW_TAG" | while read -r rule; do
                local del_rule="${rule/-A /-D }"
                eval "iptables -t raw $del_rule" 2>/dev/null || true
            done
        done
        for i in {1..10}; do
            iptables -t mangle -S 2>/dev/null | grep -q "$PAQX_FW_TAG" || break
            iptables -t mangle -S 2>/dev/null | grep "$PAQX_FW_TAG" | while read -r rule; do
                local del_rule="${rule/-A /-D }"
                eval "iptables -t mangle $del_rule" 2>/dev/null || true
            done
        done
        for i in {1..10}; do
            iptables -S 2>/dev/null | grep -q "$PAQX_FW_TAG" || break
            iptables -S 2>/dev/null | grep "$PAQX_FW_TAG" | while read -r rule; do
                local del_rule="${rule/-A /-D }"
                eval "iptables $del_rule" 2>/dev/null || true
            done
        done
    fi
    
    if command -v ip6tables >/dev/null 2>&1; then
        local i
        for i in {1..10}; do
            ip6tables -t raw -S 2>/dev/null | grep -q "$PAQX_FW_TAG" || break
            ip6tables -t raw -S 2>/dev/null | grep "$PAQX_FW_TAG" | while read -r rule; do
                local del_rule="${rule/-A /-D }"
                eval "ip6tables -t raw $del_rule" 2>/dev/null || true
            done
        done
        for i in {1..10}; do
            ip6tables -t mangle -S 2>/dev/null | grep -q "$PAQX_FW_TAG" || break
            ip6tables -t mangle -S 2>/dev/null | grep "$PAQX_FW_TAG" | while read -r rule; do
                local del_rule="${rule/-A /-D }"
                eval "ip6tables -t mangle $del_rule" 2>/dev/null || true
            done
        done
        for i in {1..10}; do
            ip6tables -S 2>/dev/null | grep -q "$PAQX_FW_TAG" || break
            ip6tables -S 2>/dev/null | grep "$PAQX_FW_TAG" | while read -r rule; do
                local del_rule="${rule/-A /-D }"
                eval "ip6tables $del_rule" 2>/dev/null || true
            done
        done
    fi
    
    log_success "All paqx firewall rules removed."
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
    echo "1) Simple (Fast mode, key only - no extra params)"
    echo "2) Automatic (Recommended - tuned to server specs)"
    echo "3) Manual (Configure all protocol values)"
    read -p "Select [1]: " p_mode
    p_mode=${p_mode:-1}
    
    if [ "$p_mode" = "3" ]; then
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
        SRV_PROTO_MODE=manual
    elif [ "$p_mode" = "2" ]; then
        SRV_PROTO_MODE=auto
    else
        SRV_PROTO_MODE=simple
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
    
    mkdir -p "$CONF_DIR"
    
    if [ "$SRV_PROTO_MODE" = "simple" ]; then
        # Simple: just mode + key, like paqctl
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
    key: "${SRV_KEY}"
EOF
    elif [ "$SRV_PROTO_MODE" = "manual" ]; then
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
    else
        # Auto: calculate based on server specs
        calculate_config
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
    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    wdelay: false
    acknodelay: true
    mtu: 1350
    rcvwnd: $CONF_RCVWND
    sndwnd: $CONF_SNDWND
    block: "aes"
    key: "${SRV_KEY}"
    smuxbuf: 4194304
    streambuf: 2097152
    dshard: 10
    pshard: 3
EOF
    fi

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
                OLD_PORT=$(grep 'addr: ":' "$CONF_FILE" | head -1 | grep -oP ':\K[0-9]+')
                
                # Update listen addr
                sed -i "s/addr: \":$OLD_PORT\"/addr: \":$NEW_PORT\"/" "$CONF_FILE"
                # Update ipv4 addr (any IP:PORT pattern)
                sed -i "s/\(addr: \"[0-9.]*:\)$OLD_PORT\"/\1$NEW_PORT\"/" "$CONF_FILE"
                
                # Remove old port rules, apply new ones
                [ -n "$OLD_PORT" ] && remove_firewall "$OLD_PORT"
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
                echo -e "\n${YELLOW}--- Change Protocol Mode ---${NC}"
                echo "1) Simple (Fast mode, key only)"
                echo "2) Automatic (Tuned to server specs)"
                echo "3) Manual (Configure all values)"
                read -p "Select: " pm
                
                # Read current key from config
                local cur_key=$(grep 'key:' "$CONF_FILE" | head -1 | grep -oP '"[^"]*"' | tr -d '"')
                
                if [ "$pm" = "1" ]; then
                    # Rewrite transport section to simple
                    # Keep everything above transport, rewrite transport
                    local tmp_head=$(sed -n '1,/^transport:/{ /^transport:/!p }' "$CONF_FILE")
                    cat > "$CONF_FILE" <<EOF
${tmp_head}
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    key: "${cur_key}"
EOF
                    log_success "Switched to Simple mode."
                elif [ "$pm" = "2" ]; then
                    calculate_config
                    local tmp_head=$(sed -n '1,/^transport:/{ /^transport:/!p }' "$CONF_FILE")
                    cat > "$CONF_FILE" <<EOF
${tmp_head}
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    wdelay: false
    acknodelay: true
    mtu: 1350
    rcvwnd: $CONF_RCVWND
    sndwnd: $CONF_SNDWND
    block: "aes"
    key: "${cur_key}"
    smuxbuf: 4194304
    streambuf: 2097152
    dshard: 10
    pshard: 3
EOF
                    log_success "Switched to Automatic mode."
                elif [ "$pm" = "3" ]; then
                    echo -e "\n${YELLOW}--- Protocol Settings ---${NC}"
                    echo "Enter values (press Enter for default):"
                    read -p "nodelay [1]: " val_nd; val_nd=${val_nd:-1}
                    read -p "interval [10]: " val_iv; val_iv=${val_iv:-10}
                    read -p "resend [2]: " val_rs; val_rs=${val_rs:-2}
                    read -p "nocongestion [1]: " val_nc; val_nc=${val_nc:-1}
                    read -p "wdelay [false]: " val_wd; val_wd=${val_wd:-false}
                    read -p "acknodelay [true]: " val_an; val_an=${val_an:-true}
                    read -p "mtu [1350]: " val_mt; val_mt=${val_mt:-1350}
                    read -p "rcvwnd [1024]: " val_rw; val_rw=${val_rw:-1024}
                    read -p "sndwnd [1024]: " val_sw; val_sw=${val_sw:-1024}
                    read -p "block [aes]: " val_bl; val_bl=${val_bl:-aes}
                    read -p "smuxbuf [4194304]: " val_sb; val_sb=${val_sb:-4194304}
                    read -p "streambuf [2097152]: " val_stb; val_stb=${val_stb:-2097152}
                    read -p "dshard [10]: " val_ds; val_ds=${val_ds:-10}
                    read -p "pshard [3]: " val_ps; val_ps=${val_ps:-3}
                    
                    local tmp_head=$(sed -n '1,/^transport:/{ /^transport:/!p }' "$CONF_FILE")
                    cat > "$CONF_FILE" <<EOF
${tmp_head}
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    nodelay: $val_nd
    interval: $val_iv
    resend: $val_rs
    nocongestion: $val_nc
    wdelay: $val_wd
    acknodelay: $val_an
    mtu: $val_mt
    rcvwnd: $val_rw
    sndwnd: $val_sw
    block: "$val_bl"
    key: "${cur_key}"
    smuxbuf: $val_sb
    streambuf: $val_stb
    dshard: $val_ds
    pshard: $val_ps
EOF
                    log_success "Manual protocol settings applied."
                else
                    log_warn "Invalid selection."
                    continue
                fi
                
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            0|*) return ;;
        esac
    done
}

# --- Uninstall ---

remove_server() {
    echo -e "${RED}${BOLD}WARNING: This will COMPLETELY remove PaqX Server.${NC}"
    echo ""
    echo "  This will remove:"
    echo "  - PaqX service (systemd)"
    echo "  - paqet binary"
    echo "  - All configuration files"
    echo "  - Firewall/iptables rules (only paqx-tagged)"
    echo "  - Kernel optimizations (only /etc/sysctl.d/99-paqx.conf)"
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
    
    # 2. Remove firewall rules (tagged only - safe for Docker/Traefik)
    local port=$(grep 'addr: ":' "$CONF_FILE" 2>/dev/null | head -1 | grep -oP ':\K[0-9]+')
    [ -n "$port" ] && remove_firewall "$port"
    remove_all_paqx_firewall_rules
    
    # 3. Remove kernel optimizations (separate file only)
    log_info "Reverting kernel optimizations..."
    revert_kernel
    # Also clean legacy entries from old versions that wrote to sysctl.conf
    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.ipv4.tcp_fastopen=3/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/fs.file-max = 1000000/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.core.rmem_max = 33554432/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.core.wmem_max = 33554432/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.core.rmem_default = 16777216/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.core.wmem_default = 16777216/d' /etc/sysctl.conf 2>/dev/null || true
    
    # 4. Kill any remaining paqet processes
    pkill -f "paqet" 2>/dev/null || true
    
    # 5. Remove files
    log_info "Removing files..."
    rm -f "$BINARY_PATH"
    rm -rf "$CONF_DIR"
    rm -rf "$PAQX_ROOT"
    rm -f "/usr/bin/paqx"
    rm -f "/usr/local/bin/paqx"
    
    echo ""
    log_success "PaqX Server completely uninstalled."
}
