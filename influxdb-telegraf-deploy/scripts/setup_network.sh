#!/bin/bash

# Script tạo mạng Docker
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
check_error() { if [ $? -ne 0 ]; then echo -e "\033[0;31mLỗi: $1\033[0m"; exit 1; fi; }
source "$(dirname "$0")/../.env"

log "Thiết lập mạng Docker: $NETWORK_NAME..."
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    docker network create "$NETWORK_NAME"
    check_error "Không thể tạo mạng $NETWORK_NAME"
fi
log "\033[0;32mMạng $NETWORK_NAME đã sẵn sàng.\033[0m"
