#!/bin/bash

source "$LIB_DIR/core.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/network.sh"

install_client_linux() {
    echo -e "\n${BOLD}--- Client Configuration ---${NC}"
    read -p "Server IP: " SRV_IP
    read -p "Server Port: " SRV_PORT
    read -p "Encryption Key: " SRV_KEY
    
    echo -e "\n--- Configuration Mode ---"
    echo "1) Automatic (Recommended Defaults)"
    echo "2) Manual (Advanced Protocol Settings)"
    read -p "Select [1]: " c_mode
    c_mode=${c_mode:-1}
    
    # Defaults
    CONF_MTU=1350
    CONF_SNDWND=1024
    CONF_RCVWND=1024
    CONF_MODE="fast"
    
    if [ "$c_mode" = "2" ]; then
        read -p "MTU [$CONF_MTU]: " CONF_MTU
        CONF_MTU=${CONF_MTU:-1350}
        read -p "SndWnd [$CONF_SNDWND]: " CONF_SNDWND
        CONF_SNDWND=${CONF_SNDWND:-1024}
        read -p "RcvWnd [$CONF_RCVWND]: " CONF_RCVWND
        CONF_RCVWND=${CONF_RCVWND:-1024}
        # Could add more per chart, but these are key.
    fi

    echo -e "\n--- Local Listener ---"
    echo "1) Default (1080)"
    echo "2) Custom"
    read -p "Select: " l_opt
    if [ "$l_opt" = "2" ]; then
        read -p "Local SOCKS5 Port: " LOC_PORT
    else
        LOC_PORT=1080
    fi
    
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
    mode: "$CONF_MODE"
    mtu: $CONF_MTU
    sndwnd: $CONF_SNDWND
    rcvwnd: $CONF_RCVWND
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
