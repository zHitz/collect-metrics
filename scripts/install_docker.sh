#!/bin/bash

# Script cài đặt Docker
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
check_error() { if [ $? -ne 0 ]; then echo -e "\033[0;31mLỗi: $1\033[0m"; exit 1; fi; }

log "Kiểm tra Docker..."
if ! command -v docker &> /dev/null; then
    log "Cài đặt Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    check_error "Không thể cài đặt Docker"
    sudo systemctl start docker
    sudo systemctl enable docker
fi
log "\033[0;32mDocker đã sẵn sàng.\033[0m"

# Cài docker-compose nếu chưa có
if ! command -v docker-compose &> /dev/null; then
    log "Cài đặt Docker Compose..."
    sudo apt-get install -y docker-compose
    check_error "Không thể cài đặt Docker Compose"
fi
log "\033[0;32mDocker Compose đã sẵn sàng.\033[0m"
