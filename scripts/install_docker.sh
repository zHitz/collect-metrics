#!/bin/bash

# Script cài đặt Docker
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
check_error() { if [ $? -ne 0 ]; then echo -e "\033[0;31mLỗi: $1\033[0m"; exit 1; fi; }

detect_os() {
    # Detect the operating system
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        if type lsb_release >/dev/null 2>&1; then
            OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
            VERSION=$(lsb_release -sr)
        else
            OS=$(uname -s)
            VERSION=$(uname -r)
        fi
    fi
    log "Phát hiện hệ điều hành: $OS $VERSION"
}

log "Kiểm tra Docker..."
if ! command -v docker &> /dev/null; then
    log "Cài đặt Docker..."
    
    detect_os
    
    case "$OS" in
        "ubuntu")
            # Ubuntu installation
            sudo apt-get update
            sudo apt-get install -y docker.io
            check_error "Không thể cài đặt Docker"
            sudo systemctl start docker
            sudo systemctl enable docker
            ;;
        "centos" | "rhel" | "fedora" | "amzn")
            # CentOS/RHEL/Fedora/Amazon Linux installation
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io
            check_error "Không thể cài đặt Docker"
            sudo systemctl start docker
            sudo systemctl enable docker
            ;;
        *)
            log "Hệ điều hành không được hỗ trợ: $OS"
            log "Vui lòng cài đặt Docker thủ công: https://docs.docker.com/engine/install/"
            exit 1
            ;;
    esac
fi
log "\033[0;32mDocker đã sẵn sàng.\033[0m"

# Cài docker compose plugin (bản mới) nếu chưa có
if ! command -v docker compose &> /dev/null; then
    log "Cài đặt Docker Compose (plugin)..."
    case "$OS" in
        "ubuntu")
            sudo apt-get update
            sudo apt-get install -y docker-compose-plugin
            ;;
        "centos" | "rhel" | "fedora" | "amzn")
            # Cài đặt plugin compose cho Docker trên CentOS/RHEL/Fedora/Amazon Linux
            sudo mkdir -p /usr/libexec/docker/cli-plugins
            sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.7/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
            sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
            ;;
        *)
            log "Vui lòng cài đặt Docker Compose plugin thủ công: https://docs.docker.com/compose/install/"
            exit 1
            ;;
    esac
    check_error "Không thể cài đặt Docker Compose plugin"
fi
log "\033[0;32mDocker Compose (plugin) đã sẵn sàng.\033[0m"
