#!/bin/bash

################################################################################
# Restart/Redeploy Script
# This script safely restarts the monitoring system
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

# Load environment variables
load_env() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
        log_success "Environment variables loaded"
    else
        log_error ".env file not found!"
        exit 1
    fi
}

# Stop all services
stop_services() {
    log_info "Stopping all monitoring services..."
    
    if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        cd "$PROJECT_ROOT"
        
        # Stop all containers
        if docker compose ps -q | grep -q .; then
            docker compose down --remove-orphans
            log_success "Services stopped"
        else
            log_info "No running services found"
        fi
    else
        log_warning "docker-compose.yml not found"
    fi
}

# Clean up Docker resources
cleanup_docker() {
    log_info "Cleaning up Docker resources..."
    
    # Remove stopped containers
    docker container prune -f
    
    # Remove unused networks
    docker network prune -f
    
    # Remove unused images (optional)
    if [ "${CLEAN_IMAGES:-false}" = "true" ]; then
        log_warning "Removing unused images (CLEAN_IMAGES=true)"
        docker image prune -f
    fi
    
    # Remove unused volumes (optional - be careful!)
    if [ "${CLEAN_VOLUMES:-false}" = "true" ]; then
        log_warning "Removing unused volumes (CLEAN_VOLUMES=true)"
        docker volume prune -f
    fi
    
    log_success "Docker cleanup completed"
}

# Check and pull latest images
update_images() {
    log_info "Checking for image updates..."
    
    cd "$PROJECT_ROOT"
    
    # Get profiles
    PROFILES=""
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        PROFILES="$PROFILES --profile snmp"
    fi
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        PROFILES="$PROFILES --profile exec"
    fi
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        PROFILES="$PROFILES --profile alerting"
    fi
    
    # Pull latest images
    if docker compose $PROFILES pull; then
        log_success "Images updated"
    else
        log_warning "Some images failed to update"
    fi
}

# Fix permissions
fix_permissions() {
    log_info "Fixing permissions..."
    
    # Grafana permissions (user 472)
    if [ -d "$PROJECT_ROOT/data/grafana" ]; then
        sudo chown -R 472:472 "$PROJECT_ROOT/data/grafana"
        sudo chmod -R 755 "$PROJECT_ROOT/data/grafana"
    fi
    
    # InfluxDB permissions (user 472)
    if [ -d "$PROJECT_ROOT/data/influxdb" ]; then
        sudo chown -R 472:472 "$PROJECT_ROOT/data/influxdb"
        sudo chmod -R 755 "$PROJECT_ROOT/data/influxdb"
    fi
    
    if [ -d "$PROJECT_ROOT/data/influxdb-config" ]; then
        sudo chown -R 472:472 "$PROJECT_ROOT/data/influxdb-config"
        sudo chmod -R 755 "$PROJECT_ROOT/data/influxdb-config"
    fi
    
    # Prometheus permissions (user 65534)
    if [ -d "$PROJECT_ROOT/data/prometheus" ]; then
        sudo chown -R 65534:65534 "$PROJECT_ROOT/data/prometheus"
        sudo chmod -R 755 "$PROJECT_ROOT/data/prometheus"
    fi
    
    log_success "Permissions fixed"
}

# Start services
start_services() {
    log_info "Starting monitoring services..."
    
    cd "$PROJECT_ROOT"
    
    # Get profiles
    PROFILES=""
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        PROFILES="$PROFILES --profile snmp"
    fi
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        PROFILES="$PROFILES --profile exec"
    fi
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        PROFILES="$PROFILES --profile alerting"
    fi
    
    # Start services
    if docker compose $PROFILES up -d --build; then
        log_success "Services started"
    else
        log_error "Failed to start services"
        return 1
    fi
    
    # Wait for services
    log_info "Waiting for services to be ready..."
    sleep 15
    
    # Check status
    log_info "Service status:"
    docker compose $PROFILES ps
}

# Check service health
check_health() {
    log_info "Checking service health..."
    
    local services=("grafana" "prometheus" "node-exporter")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if docker compose ps "$service" | grep -q "Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Some services failed to start: ${failed_services[*]}"
        log_info "Check logs with: docker compose logs [service-name]"
        return 1
    fi
    
    log_success "All services are healthy"
}

# Show restart summary
show_summary() {
    echo ""
    echo "=================================="
    echo "Restart Summary"
    echo "=================================="
    echo ""
    echo "Services restarted:"
    echo "  - Grafana: http://localhost:${GRAFANA_PORT:-3000}"
    echo "  - Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "  - InfluxDB: http://localhost:${INFLUXDB_PORT:-8086}"
    echo ""
    echo "To view logs: docker compose logs -f [service-name]"
    echo "To stop services: docker compose down"
    echo ""
}

# Main restart flow
main() {
    echo ""
    echo "======================================"
    echo "Monitoring System Restart"
    echo "======================================"
    echo ""
    
    # Check if running as root
    check_root
    
    # Load environment variables
    load_env
    
    # Stop services
    stop_services
    
    # Cleanup Docker resources
    cleanup_docker
    
    # Update images (optional)
    if [ "${UPDATE_IMAGES:-true}" = "true" ]; then
        update_images
    fi
    
    # Fix permissions
    fix_permissions
    
    # Start services
    start_services
    
    # Check health
    check_health
    
    # Show summary
    show_summary
    
    log_success "Restart completed successfully!"
}

# Run main function
main "$@" 