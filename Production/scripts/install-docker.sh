#!/bin/bash

################################################################################
# Docker Installation Script
# Supports: Ubuntu, Debian, CentOS, RHEL, Rocky Linux, AlmaLinux
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
    
    log_info "Detected OS: $OS $OS_VERSION"
}

# Install Docker on Ubuntu/Debian
install_docker_debian() {
    log_info "Installing Docker on Ubuntu/Debian..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up stable repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    sudo apt-get update
    
    # Install Docker Engine
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    log_success "Docker installed successfully on Ubuntu/Debian"
}

# Install Docker on CentOS/RHEL/Rocky/Alma
install_docker_rhel() {
    log_info "Installing Docker on RHEL-based system..."
    
    # Remove old versions
    sudo yum remove -y docker \
                       docker-client \
                       docker-client-latest \
                       docker-common \
                       docker-latest \
                       docker-latest-logrotate \
                       docker-logrotate \
                       docker-engine \
                       podman \
                       runc || true
    
    # Install prerequisites
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    
    # Add Docker repository
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker Engine
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker installed successfully on RHEL-based system"
}

# Configure Docker post-installation
configure_docker() {
    log_info "Configuring Docker..."
    
    # Create docker group if it doesn't exist
    if ! getent group docker > /dev/null 2>&1; then
        sudo groupadd docker
    fi
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Configure Docker daemon
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true
}
EOF
    
    # Restart Docker
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    # Enable Docker to start on boot
    sudo systemctl enable docker
    
    log_success "Docker configured successfully"
}

# Test Docker installation
test_docker() {
    log_info "Testing Docker installation..."
    
    # Test Docker
    if sudo docker run --rm hello-world > /dev/null 2>&1; then
        log_success "Docker is working correctly"
    else
        log_error "Docker test failed"
        exit 1
    fi
    
    # Test Docker Compose
    if docker compose version > /dev/null 2>&1; then
        log_success "Docker Compose is working correctly"
    else
        log_warning "Docker Compose plugin not found, installing standalone version..."
        install_docker_compose_standalone
    fi
}

# Install Docker Compose standalone (fallback)
install_docker_compose_standalone() {
    log_info "Installing Docker Compose standalone..."
    
    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # Download Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Make executable
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for docker compose command
    sudo ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose
    
    log_success "Docker Compose standalone installed"
}

# Main installation flow
main() {
    echo ""
    echo "======================================"
    echo "Docker Installation Script"
    echo "======================================"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        log_error "Please run this script as a regular user, not as root"
        exit 1
    fi
    
    # Detect OS
    detect_os
    
    # Install based on OS
    case $OS in
        ubuntu|debian)
            install_docker_debian
            ;;
        centos|rhel|rocky|almalinux|fedora)
            install_docker_rhel
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    # Configure Docker
    configure_docker
    
    # Test installation
    test_docker
    
    echo ""
    log_success "Docker installation completed!"
    log_warning "Please log out and log back in for group changes to take effect"
    log_info "Or run: newgrp docker"
    echo ""
}

# Run main function
main "$@"