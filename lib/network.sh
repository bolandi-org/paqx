#!/bin/bash
[ -n "$_NETWORK_SOURCED" ] && return 0
_NETWORK_SOURCED=1

get_public_ip() {
    curl -s --max-time 5 http://checkip.amazonaws.com || echo "Unknown"
}

scan_interface() {
    # Try getting the interface used for the default route
    if [ "$(detect_os)" = "openwrt" ]; then
        ip route show default | awk '/default/ {print $5}'
    else
        ip route get 8.8.8.8 | awk '{print $5; exit}'
    fi
}

get_gateway_mac() {
    local gw_ip
    gw_ip=$(ip route show default | awk '/default/ {print $3}')
    if [ -n "$gw_ip" ]; then
        ip neigh show "$gw_ip" | awk '/lladdr/{print $5; exit}'
    fi
}
