#!/bin/bash

source "$LIB_DIR/core.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/network.sh"

install_client_openwrt() {
    log_info "Installing for OpenWrt..."
    opkg update
    opkg install curl libpcap-dev kmod-nft-bridge
    
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
  - listen: "0.0.0.0:$LOC_PORT"
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

    cat > "$SERVICE_FILE_OPENWRT" <<EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command $BINARY_PATH run -c $CONF_FILE
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}
EOF
    chmod +x "$SERVICE_FILE_OPENWRT"
    /etc/init.d/paqx enable
    /etc/init.d/paqx start
    
    log_success "OpenWrt Client started on port $LOC_PORT"
}

configure_client_openwrt() {
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
            
            sed -i "s/addr: .*/addr: \"$NEW_IP:$NEW_PORT\"/" "$CONF_FILE"
            sed -i "s/key: .*/key: \"$NEW_KEY\"/" "$CONF_FILE"
            
            log_success "Server info updated."
            ;;
        2)
            echo -e "${YELLOW}Protocol Tuning (Advanced)${NC}"
            echo "1) Fast"
            echo "2) Normal"
            read -p "Select: " p_opt
            if [ "$p_opt" = "1" ]; then
                sed -i 's/mode: .*/mode: "fast"/' "$CONF_FILE"
                log_success "Set to Fast mode."
            elif [ "$p_opt" = "2" ]; then
                sed -i 's/mode: .*/mode: "normal"/' "$CONF_FILE"
                log_success "Set to Normal mode."
            fi
            ;;
        *) return ;;
    esac
    
    log_info "Restarting service..."
    /etc/init.d/paqx restart
    log_success "Configuration applied."
}
