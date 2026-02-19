#!/bin/bash

source "$LIB_DIR/core.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/network.sh"

# --- FIRST RUN: Pre-install prompts ---

CL_SRV_IP=""
CL_SRV_PORT=""
CL_SRV_KEY=""
CL_LOC_PORT=1080

client_pre_install_linux() {
    echo -e "\n${BOLD}--- Client Installation ---${NC}"
    read -p "Server IP: " CL_SRV_IP
    read -p "Server Port: " CL_SRV_PORT
    read -p "Encryption Key: " CL_SRV_KEY
    
    echo ""
    echo "1) Automatic (Recommended Defaults)"
    echo "2) Manual (Configure all protocol values)"
    read -p "Select [1]: " c_mode
    c_mode=${c_mode:-1}
    
    read -p "Local Forward Port [1080]: " CL_LOC_PORT
    CL_LOC_PORT=${CL_LOC_PORT:-1080}
    
    if [ "$c_mode" = "2" ]; then
        echo -e "\n${YELLOW}--- Protocol Settings ---${NC}"
        echo "Enter values (press Enter for default):"
        read -p "conn [1]: " P_CONN; P_CONN=${P_CONN:-1}
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
    else
        P_CONN=1; P_NODELAY=1; P_INTERVAL=10; P_RESEND=2; P_NOCONG=1
        P_WDELAY=false; P_ACKNO=true; P_MTU=1350; P_RCVWND=1024; P_SNDWND=1024
        P_BLOCK=aes; P_SMUXBUF=4194304; P_STREAMBUF=2097152; P_DSHARD=10; P_PSHARD=3
    fi
}

# --- FIRST RUN: Install client ---

install_client_linux() {
    if [ -z "$CL_SRV_IP" ]; then client_pre_install_linux; fi
    
    IFACE=$(scan_interface)
    GW_MAC=$(get_gateway_mac)
    
    mkdir -p "$CONF_DIR"
    cat > "$CONF_FILE" <<EOF
role: "client"
log:
  level: "info"
socks5:
  - listen: "127.0.0.1:$CL_LOC_PORT"
network:
  interface: "$IFACE"
  ipv4:
    addr: "0.0.0.0:0"
    router_mac: "$GW_MAC"
server:
  addr: "$CL_SRV_IP:$CL_SRV_PORT"
transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    conn: $P_CONN
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
    key: "$CL_SRV_KEY"
    smuxbuf: $P_SMUXBUF
    streambuf: $P_STREAMBUF
    dshard: $P_DSHARD
    pshard: $P_PSHARD
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
    
    log_success "Client started on 127.0.0.1:$CL_LOC_PORT"
}

# --- SECOND RUN: Settings submenu ---

configure_client_linux() {
    while true; do
        echo -e "\n${BOLD}--- Client Settings ---${NC}"
        echo "1) Change Server Config (IP:Port & Key)"
        echo "2) Change Local Port"
        echo "3) Change Protocol Setting"
        echo "0) Back"
        read -p "Select: " c_opt
        
        case $c_opt in
            1)
                read -p "New Server IP: " NEW_IP
                read -p "New Server Port: " NEW_PORT
                read -p "New Encrypted Key: " NEW_KEY
                
                # Update server addr
                sed -i "/^server:/,/^[^ ]/{s|addr: .*|addr: \"$NEW_IP:$NEW_PORT\"|}" "$CONF_FILE"
                sed -i "s/key: .*/key: \"$NEW_KEY\"/" "$CONF_FILE"
                
                log_success "Server config updated."
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            2)
                read -p "New Local Port: " NEW_LOC
                sed -i "s/listen: .*/listen: \"127.0.0.1:$NEW_LOC\"/" "$CONF_FILE"
                
                log_success "Local port changed to $NEW_LOC"
                log_info "Restarting service..."
                systemctl restart paqx
                ;;
            3)
                echo -e "\n${YELLOW}--- Protocol Settings ---${NC}"
                echo "Current values (leave blank to keep):"
                
                read -p "conn [1]: " val; [ -n "$val" ] && sed -i "s/conn: .*/conn: $val/" "$CONF_FILE"
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

remove_client_linux() {
    echo -e "${RED}${BOLD}WARNING: This will remove PaqX Client completely.${NC}"
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
    
    log_success "PaqX Client uninstalled."
}
