#!/bin/bash

source "$LIB_DIR/core.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/network.sh"

install_client_linux() {
    echo -e "\n${BOLD}--- Client Configuration ---${NC}"
    read -p "Server IP: " SRV_IP
    read -p "Server Port: " SRV_PORT
    read -p "Encryption Key: " SRV_KEY
    read -p "Local SOCKS5 Port [1080]: " LOC_PORT
    LOC_PORT=${LOC_PORT:-1080}
    
    IFACE=$(scan_interface)
    GW_MAC=$(get_gateway_mac)
    
    mkdir -p "$CONF_DIR"
    cat > "$CONF_FILE" <<EOF
role: "client"
log:
  level: "info"
socks5:
  - listen: "127.0.0.1:$LOC_PORT"
network:
  interface: "$IFACE"
  ipv4:
    addr: "0.0.0.0:0"
    router_mac: "$GW_MAC"
server:
  addr: "$SRV_IP:$SRV_PORT"
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    key: "$SRV_KEY"
EOF

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
    
    log_success "Client started on 127.0.0.1:$LOC_PORT"
}

configure_client_linux() {
    echo -e "\n${BOLD}--- Client Settings ---${NC}"
    echo "1) Change Server Info (IP:Port, Key)"
    echo "2) Protocol Tuning (Buffer/MTU)"
    echo "0) Back"
    read -p "Select: " c_opt
    
    case $c_opt in
        1)
            read -p "New Server IP: " NEW_IP
            read -p "New Server Port: " NEW_PORT
            read -p "New Key (Pre-shared): " NEW_KEY
            
            # Simple sed replacement for YAML (assuming structure is maintained)
            # This is brittle but works if file format is preserved. 
            # Ideally use yq if available, but staying dependency-free.
            sed -i "s/addr: .*/addr: \"$NEW_IP:$NEW_PORT\"/" "$CONF_FILE"
            sed -i "s/key: .*/key: \"$NEW_KEY\"/" "$CONF_FILE"
            
            log_success "Server info updated."
            ;;
        2)
            echo -e "${YELLOW}Protocol Tuning (Advanced)${NC}"
            echo "Select preset:"
            echo "1) Fast (Low Latency, Higher Bandwidth Usage)"
            echo "2) Normal (Balanced)"
            read -p "Select: " p_opt
            
            if [ "$p_opt" = "1" ]; then
                sed -i 's/mode: .*/mode: "fast"/' "$CONF_FILE"
                # Add/Update other params if they exist, or append?
                # For simplicity, just ensuring mode is set. 
                # Ideally, we would rewrite the file cleanly.
                log_success "Set to Fast mode."
            elif [ "$p_opt" = "2" ]; then
                sed -i 's/mode: .*/mode: "normal"/' "$CONF_FILE"
                log_success "Set to Normal mode."
            fi
            ;;
        *) return ;;
    esac
    
    log_info "Restarting service..."
    systemctl restart paqx
    log_success "Configuration applied."
}

remove_client_linux() {
    echo -e "${RED}${BOLD}WARNING: This will remove PaqX Client, config, and binaries.${NC}"
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
    
    log_success "PaqX Client uninstalled."
}
