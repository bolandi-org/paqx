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
    
    # Defaults
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
    
    # IPTables fallback
    iptables -t raw -I PREROUTING -p tcp --dport "$port" -j NOTRACK >/dev/null 2>&1
    iptables -t raw -I OUTPUT -p tcp --sport "$port" -j NOTRACK >/dev/null 2>&1
    iptables -t mangle -I OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP >/dev/null 2>&1
    log_success "IPTables rules applied."
}

install_server() {
    optimize_kernel
    
    echo -e "\n${BOLD}--- Server Configuration ---${NC}"
    read -p "Listen Port [8443]: " PORT
    PORT=${PORT:-8443}
    
    KEY=$(generate_key)
    log_success "Key Generated: $KEY"
    
    calculate_config
    IFACE=$(scan_interface)
    
    mkdir -p "$CONF_DIR"
    cat > "$CONF_FILE" <<EOF
role: "server"
log:
  level: "info"
listen:
  addr: ":$PORT"
network:
  interface: "$IFACE"
  ipv4:
    addr: "0.0.0.0:$PORT"
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    nodelay: 1
    interval: 10
    resend: 2
    nocongestion: 1
    sndwnd: $CONF_SNDWND
    rcvwnd: $CONF_RCVWND
    key: "$KEY"
  pcap:
    sockbuf: $CONF_SOCKBUF
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
    
    apply_firewall "$PORT"
    
    PUB_IP=$(get_public_ip)
    
    echo -e "\n${GREEN}${BOLD}Server Installed!${NC}"
    echo -e "IP:   ${YELLOW}$PUB_IP${NC}"
    echo -e "Port: ${YELLOW}$PORT${NC}"
    echo -e "Key:  ${YELLOW}$KEY${NC}"
}

configure_server() {
    echo -e "\n${BOLD}--- Server Settings ---${NC}"
    echo "1) Change Listen Port"
    echo "2) Reset Encryption Key"
    echo "0) Back"
    read -p "Select: " s_opt
    
    case $s_opt in
        1)
            read -p "New Port: " NEW_PORT
            # Remove old firewall rules if possible (tricky without tracking old port)
            # For now, just apply new rules. 
            # Ideally we read old port from config.
            OLD_PORT=$(grep "addr: \":" "$CONF_FILE" | cut -d ':' -f 3 | tr -d '"')
            
            sed -i "s/addr: \":$OLD_PORT\"/addr: \":$NEW_PORT\"/" "$CONF_FILE"
            sed -i "s/addr: \"0.0.0.0:$OLD_PORT\"/addr: \"0.0.0.0:$NEW_PORT\"/" "$CONF_FILE"
            
            apply_firewall "$NEW_PORT"
            log_success "Port updated to $NEW_PORT"
            ;;
        2)
            NEW_KEY=$(generate_key)
            sed -i "s/key: .*/key: \"$NEW_KEY\"/" "$CONF_FILE"
            log_success "New Key: $NEW_KEY"
            ;;
        *) return ;;
    esac
    
    log_info "Restarting service..."
    systemctl restart paqx
}

remove_server() {
    echo -e "${RED}${BOLD}WARNING: This will remove PaqX Server, config, and binaries.${NC}"
    read -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then return; fi
    
    log_info "Stopping service..."
    systemctl stop paqx
    systemctl disable paqx
    rm "$SERVICE_FILE_LINUX"
    systemctl daemon-reload
    
    log_info "Removing files..."
    rm -f "$BINARY_PATH"
    rm -rf "$CONF_DIR"
    
    # Firewall cleanup is tricky without explicit rule deletion. 
    # Flushing raw/mangle tables completely is dangerous.
    # Leaving rules is safer than breaking other things, but prompt user?
    # For now, we leave rules or try simple deletion if port known.
    
    log_success "PaqX Server uninstalled."
}
