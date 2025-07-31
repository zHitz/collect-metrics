#!/bin/bash

################################################################################
# Fix Permissions Script
# This script fixes permissions for Docker containers
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Fix permissions for all data directories
fix_permissions() {
    log_info "Fixing permissions for Docker containers..."
    
    # Grafana permissions (user 472)
    if [ -d "$PROJECT_ROOT/data/grafana" ]; then
        log_info "Setting Grafana permissions (user 472)..."
        sudo chown -R 472:472 "$PROJECT_ROOT/data/grafana"
        sudo chmod -R 755 "$PROJECT_ROOT/data/grafana"
        log_success "Grafana permissions set"
    else
        log_warning "Grafana data directory not found"
    fi
    
    # InfluxDB data permissions (user 472)
    if [ -d "$PROJECT_ROOT/data/influxdb" ]; then
        log_info "Setting InfluxDB data permissions (user 472)..."
        sudo chown -R 472:472 "$PROJECT_ROOT/data/influxdb"
        sudo chmod -R 755 "$PROJECT_ROOT/data/influxdb"
        log_success "InfluxDB data permissions set"
    else
        log_warning "InfluxDB data directory not found"
    fi
    
    # InfluxDB config permissions (user 472)
    if [ -d "$PROJECT_ROOT/data/influxdb-config" ]; then
        log_info "Setting InfluxDB config permissions (user 472)..."
        sudo chown -R 472:472 "$PROJECT_ROOT/data/influxdb-config"
        sudo chmod -R 755 "$PROJECT_ROOT/data/influxdb-config"
        log_success "InfluxDB config permissions set"
    else
        log_warning "InfluxDB config directory not found"
    fi
    
    # Prometheus permissions (user 65534 - nobody)
    if [ -d "$PROJECT_ROOT/data/prometheus" ]; then
        log_info "Setting Prometheus permissions (user 65534)..."
        sudo chown -R 65534:65534 "$PROJECT_ROOT/data/prometheus"
        sudo chmod -R 755 "$PROJECT_ROOT/data/prometheus"
        log_success "Prometheus permissions set"
    else
        log_warning "Prometheus data directory not found"
    fi
    
    # AlertManager permissions (user 65534 - nobody)
    if [ -d "$PROJECT_ROOT/data/alertmanager" ]; then
        log_info "Setting AlertManager permissions (user 65534)..."
        sudo chown -R 65534:65534 "$PROJECT_ROOT/data/alertmanager"
        sudo chmod -R 755 "$PROJECT_ROOT/data/alertmanager"
        log_success "AlertManager permissions set"
    else
        log_warning "AlertManager data directory not found"
    fi
    
    # Config files permissions (readable by containers)
    if [ -d "$PROJECT_ROOT/configs" ]; then
        log_info "Setting configs permissions..."
        sudo chmod -R 644 "$PROJECT_ROOT/configs"
        sudo find "$PROJECT_ROOT/configs" -type d -exec chmod 755 {} \;
        log_success "Configs permissions set"
    else
        log_warning "Configs directory not found"
    fi
    
    # Dashboard files permissions
    if [ -d "$PROJECT_ROOT/dashboards" ]; then
        log_info "Setting dashboards permissions..."
        sudo chmod -R 644 "$PROJECT_ROOT/dashboards"
        sudo find "$PROJECT_ROOT/dashboards" -type d -exec chmod 755 {} \;
        log_success "Dashboards permissions set"
    else
        log_warning "Dashboards directory not found"
    fi
    
    # Exec scripts permissions
    if [ -d "$PROJECT_ROOT/exec-scripts" ]; then
        log_info "Setting exec-scripts permissions..."
        sudo chmod -R 755 "$PROJECT_ROOT/exec-scripts"
        log_success "Exec-scripts permissions set"
    else
        log_warning "Exec-scripts directory not found"
    fi
    
    log_success "All permissions fixed successfully!"
}

# Show current permissions
show_permissions() {
    log_info "Current permissions:"
    echo ""
    
    if [ -d "$PROJECT_ROOT/data" ]; then
        echo "Data directories:"
        ls -la "$PROJECT_ROOT/data/"
        echo ""
    fi
    
    if [ -d "$PROJECT_ROOT/configs" ]; then
        echo "Configs directory:"
        ls -la "$PROJECT_ROOT/configs/"
        echo ""
    fi
    
    if [ -d "$PROJECT_ROOT/dashboards" ]; then
        echo "Dashboards directory:"
        ls -la "$PROJECT_ROOT/dashboards/"
        echo ""
    fi
}

# Main function
main() {
    echo ""
    echo "======================================"
    echo "Fix Permissions Script"
    echo "======================================"
    echo ""
    
    # Check if running as root
    check_root
    
    # Show current permissions
    show_permissions
    
    # Fix permissions
    fix_permissions
    
    echo ""
    log_success "Permissions fixed! You can now run docker-compose up -d"
    echo ""
}

# Run main function
main "$@" 