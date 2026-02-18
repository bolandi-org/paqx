#!/bin/bash
[ -n "$_CRYPTO_SOURCED" ] && return 0
_CRYPTO_SOURCED=1

generate_key() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32 | tr -d '=+/' | head -c 32
    else
        # Fallback for minimal systems
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
    fi
}
