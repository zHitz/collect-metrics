#!/bin/bash

################################################################################
# Docker Installation Script
# Uses official Docker installation method: get.docker.com
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

# Check if running as root
check_root() {
    if [ "$(id -u)" -eq 0 ]; then 
        log_error "Please run this script as a regular user, not as root"
        exit 1
    fi
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

# Install Docker using official method
install_docker() {
    log_info "Installing Docker using official installation method..."
    
    # Download Docker installation script
    log_info "Downloading Docker installation script..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    
    # Make script executable
    chmod +x get-docker.sh
    
    # Run Docker installation script
    log_info "Running Docker installation script..."
    sudo sh get-docker.sh
    
    # Clean up installation script
    rm -f get-docker.sh
    
    log_success "Docker installed successfully using official method"
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
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
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
    echo "Using official get.docker.com method"
    echo "======================================"
    echo ""
    
    # Check if running as root
    check_root
    
    # Detect OS
    detect_os
    
    # Install Docker
    install_docker
    
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