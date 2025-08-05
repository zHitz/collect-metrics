#!/bin/bash

################################################################################
# Monitoring System Deployment Script
# This script deploys a comprehensive monitoring solution
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

# Load environment variables
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${YELLOW}.env file not found. Copying from .env.example...${NC}"
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        echo -e "${GREEN}Copied .env.example to .env. Please review and update your configuration if needed.${NC}"
    else
        echo -e "${RED}Error: .env.example file not found!${NC}"
        exit 1
    fi
fi

set -a
source "$PROJECT_ROOT/.env"
set +a

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        log_info "Running Docker installation script..."
        "$SCRIPT_DIR/install-docker.sh"
    else
        log_success "Docker is installed"
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed!"
        log_info "Installing Docker Compose..."
        "$SCRIPT_DIR/install-docker.sh"
    else
        log_success "Docker Compose is installed"
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running!"
        log_info "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
}

# Stop and clean existing containers
cleanup_existing() {
    log_info "Cleaning up existing containers..."
    
    # Check if docker-compose.yml exists
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        log_warning "docker-compose.yml not found, skipping cleanup"
        return
    fi
    
    # Get profiles for cleanup
    local profiles=""
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        profiles="$profiles --profile snmp"
    fi
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        profiles="$profiles --profile exec"
    fi
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        profiles="$profiles --profile alerting"
    fi
    
    cd "$PROJECT_ROOT"
    
    # Stop all containers with profiles
    if docker compose $profiles ps -q | grep -q .; then
        log_info "Stopping existing containers with profiles: $profiles"
        docker compose $profiles down --remove-orphans
        log_success "Containers stopped"
    else
        log_info "No running containers found"
    fi
    
    # Remove stopped containers
    log_info "Removing stopped containers..."
    docker container prune -f
    
    # Remove unused networks
    log_info "Cleaning up unused networks..."
    docker network prune -f
}

# Check and pull Docker images
check_images() {
    log_info "Checking Docker images..."
    
    # Base images (always required)
    local base_images=(
        "${GRAFANA_IMAGE:-grafana/grafana:10.0.0}"
        "${PROMETHEUS_IMAGE:-prom/prometheus:v2.45.0}"
        "${NODE_EXPORTER_IMAGE:-prom/node-exporter:v1.6.0}"
    )
    
    # Optional images (based on profiles)
    local optional_images=()
    
    # Add InfluxDB if SNMP is enabled (InfluxDB is in snmp profile)
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        optional_images+=("${INFLUXDB_IMAGE:-influxdb:2.7.0}")
        optional_images+=("${TELEGRAF_IMAGE:-telegraf:1.27.0}")
    fi
    
    # Add AlertManager if alerting is enabled
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        optional_images+=("${ALERTMANAGER_IMAGE:-prom/alertmanager:v0.28.0}")
    fi
    
    # Combine all images
    local all_images=("${base_images[@]}" "${optional_images[@]}")
    
    log_info "Checking ${#all_images[@]} images based on enabled profiles..."
    
    for image in "${all_images[@]}"; do
        log_info "Checking image: $image"
        
        # Check if image exists locally
        if ! docker image inspect "$image" &> /dev/null; then
            log_info "Pulling image: $image"
            if docker pull "$image"; then
                log_success "Pulled: $image"
            else
                log_error "Failed to pull: $image"
                return 1
            fi
        else
            log_success "Image exists: $image"
        fi
    done
    
    log_success "All required images checked"
}

# Show enabled profiles
show_profiles() {
    log_info "Checking enabled profiles..."
    
    local enabled_profiles=()
    
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        enabled_profiles+=("SNMP Monitoring")
    fi
    
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        enabled_profiles+=("Custom Scripts")
    fi
    
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        enabled_profiles+=("AlertManager")
    fi
    
    if [ ${#enabled_profiles[@]} -eq 0 ]; then
        log_info "No optional profiles enabled (basic monitoring only)"
    else
        log_info "Enabled profiles: ${enabled_profiles[*]}"
    fi
}

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    
    # Data directories
    mkdir -p "$PROJECT_ROOT/data"/{influxdb,influxdb-config,grafana,prometheus}
    
    # Config directories
    mkdir -p "$PROJECT_ROOT/configs/prometheus/"{rules,targets}
    
    # Dashboard directories
    mkdir -p "$PROJECT_ROOT/dashboards"/{system,network,custom}
    
    # Scripts directory
    mkdir -p "$PROJECT_ROOT/exec-scripts"
    
    # Backup directory
    if [ "${BACKUP_ENABLED}" = "true" ]; then
        mkdir -p "$PROJECT_ROOT/backups"
    fi
    
    # Set proper permissions for Docker containers
    log_info "Setting proper permissions for Docker containers..."
    
    # Grafana needs user 472
    if [ -d "$PROJECT_ROOT/data/grafana" ]; then
        sudo chown -R 472:472 "$PROJECT_ROOT/data/grafana"
        sudo chmod -R 755 "$PROJECT_ROOT/data/grafana"
        log_info "Set Grafana permissions (user 472)"
    fi
    
    # InfluxDB needs user 472 (same as Grafana)
    if [ -d "$PROJECT_ROOT/data/influxdb" ]; then
        sudo chown -R 472:472 "$PROJECT_ROOT/data/influxdb"
        sudo chmod -R 755 "$PROJECT_ROOT/data/influxdb"
        log_info "Set InfluxDB data permissions (user 472)"
    fi
    
    if [ -d "$PROJECT_ROOT/data/influxdb-config" ]; then
        sudo chown -R 472:472 "$PROJECT_ROOT/data/influxdb-config"
        sudo chmod -R 755 "$PROJECT_ROOT/data/influxdb-config"
        log_info "Set InfluxDB config permissions (user 472)"
    fi
    
    # Prometheus needs user 65534 (nobody)
    if [ -d "$PROJECT_ROOT/data/prometheus" ]; then
        sudo chown -R 65534:65534 "$PROJECT_ROOT/data/prometheus"
        sudo chmod -R 755 "$PROJECT_ROOT/data/prometheus"
        log_info "Set Prometheus permissions (user 65534)"
    fi
    
    # Make configs readable by containers
    if [ -d "$PROJECT_ROOT/configs" ]; then
        sudo chmod -R 644 "$PROJECT_ROOT/configs"
        sudo find "$PROJECT_ROOT/configs" -type d -exec chmod 755 {} \;
        log_info "Set configs permissions (readable by containers)"
    fi
    
    log_success "Directories created and permissions set successfully"
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    # Check required environment variables
    local required_vars=(
        "COMPOSE_PROJECT_NAME"
        "INFLUXDB_USERNAME"
        "INFLUXDB_PASSWORD"
        "INFLUXDB_ORG"
        "INFLUXDB_BUCKET"
        "GRAFANA_ADMIN_USER"
        "GRAFANA_ADMIN_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done
    
    # Check if docker-compose.yml exists
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in $PROJECT_ROOT"
        return 1
    fi
    
    # Validate docker-compose.yml syntax
    if ! docker compose -f "$PROJECT_ROOT/docker-compose.yml" config &> /dev/null; then
        log_error "Invalid docker-compose.yml syntax"
        return 1
    fi
    
    log_success "Configuration validated"
}


# Check service health
check_service_health() {
    log_info "Checking service health..."
    
    # Base services (always required)
    local base_services=("grafana" "prometheus" "node-exporter")
    
    # Optional services (based on profiles)
    local optional_services=()
    
    # Add InfluxDB if SNMP is enabled
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        optional_services+=("influxdb" "telegraf")
    fi
    
    # Add AlertManager if alerting is enabled
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        optional_services+=("alertmanager")
    fi
    
    # Combine all services
    local all_services=("${base_services[@]}" "${optional_services[@]}")
    
    log_info "Checking ${#all_services[@]} services based on enabled profiles..."
    
    local failed_services=()
    
    for service in "${all_services[@]}"; do
        if docker compose -f "$PROJECT_ROOT/docker-compose.yml" ps "$service" | grep -q "Up"; then
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

# Generate configuration files
generate_configs() {
    log_info "Generating configuration files..."
    
    # Run configuration script
    "$SCRIPT_DIR/configure.sh"
    
    # Re-source environment variables after configure.sh may have updated .env
    log_info "Reloading environment variables after configuration..."
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
    
    log_success "Configuration files generated"
}

# Prepare Docker profiles based on enabled modules
prepare_docker_profiles() {
    local profiles=""
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        profiles="$profiles --profile snmp"
    fi
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        profiles="$profiles --profile exec"
    fi
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        profiles="$profiles --profile alerting"
    fi
    echo "$profiles"
}

# Deploy services
deploy_services() {
    log_info "Deploying monitoring services..."
    
    cd "$PROJECT_ROOT"
    
    # Build Telegraf image if needed (before starting services)
    build_telegraf_if_needed
    
    # Get profiles
    PROFILES=$(prepare_docker_profiles)
    
    # Start services with profiles (without --build to avoid verbose output)
    log_info "Starting services with profiles: $PROFILES"
    if docker compose $PROFILES up -d; then
        log_success "Services started successfully"
    else
        log_error "Failed to start services"
        return 1
    fi
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 15
    
    # Check service health
    check_service_health
    
    # Show service status
    log_info "Service status:"
    docker compose $PROFILES ps
}

# Build Telegraf image if SNMP is enabled
build_telegraf_if_needed() {
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        log_info "Building Telegraf image..."
        
        # Show progress indicator
        echo -n "Building Telegraf: "
        
        # Build with quiet output
        docker build \
            --build-arg TELEGRAF_IMAGE="${TELEGRAF_IMAGE:-telegraf:1.27.0}" \
            --tag "${COMPOSE_PROJECT_NAME:-monitoring}-telegraf" \
            --quiet \
            "$PROJECT_ROOT" >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC}"
            log_success "Telegraf image built successfully!"
        else
            echo -e "${RED}✗${NC}"
            log_error "Failed to build Telegraf image!"
            return 1
        fi
    fi
}

# Import default dashboards
import_dashboards() {
    log_info "Importing default dashboards..."
    
    # Wait for Grafana to be ready
    until curl -s -o /dev/null -w "%{http_code}" http://localhost:${GRAFANA_PORT}/api/health | grep -q "200"; do
        log_info "Waiting for Grafana to be ready..."
        sleep 5
    done
    
    # Create sample dashboards if they don't exist
    if [ ! -f "$PROJECT_ROOT/dashboards/server-monitoring.json" ]; then
        "$SCRIPT_DIR/utils/create-dashboards.sh"
    fi
    
    log_success "Dashboards imported"
}

deploy_portainer() {
    chmod +x "$PROJECT_ROOT/portainer/portainer-deploy.sh"
    "$PROJECT_ROOT/portainer/portainer-deploy.sh"
}

# Show deployment summary
show_summary() {
    echo ""
    echo "=================================="
    echo "Deployment Summary"
    echo "=================================="
    echo ""
    echo "Services deployed:"
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        echo "  - InfluxDB: http://localhost:${INFLUXDB_PORT}"
    fi
    echo "  - Grafana: http://localhost:${GRAFANA_PORT}"
    echo "  - Prometheus: http://localhost:${PROMETHEUS_PORT}"
    if [ "${ENABLE_PORTAINER:-false}" = "true" ]; then
        echo "  - Portainer: https://localhost:${PORTAINER_PORT}"
    fi
    echo ""
    echo "Credentials:"
    echo "  - Grafana:"
    echo "    Username: ${GRAFANA_ADMIN_USER}"
    echo "    Password: ${GRAFANA_ADMIN_PASSWORD}"
    echo ""
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        echo "  - InfluxDB:"
        echo "    Username: ${INFLUXDB_USERNAME}"
        echo "    Password: ${INFLUXDB_PASSWORD}"
        echo "    Organization: ${INFLUXDB_ORG}"
        echo "    Bucket: ${INFLUXDB_BUCKET}"
        echo ""
    fi    
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        echo "Custom Scripts: ENABLED"
        echo "  Place scripts in exec-scripts/ directory"
        echo ""
    fi
    
    echo "Next steps:"
    echo "  1. Access and change Portainer password at https://localhost:${PORTAINER_PORT}"
    echo "  2. Access Grafana at http://localhost:${GRAFANA_PORT}"
    echo "  3. Configure additional monitoring targets"
    echo "  4. Import or create custom dashboards"
    echo ""
    echo "To view logs: docker compose logs -f [service-name]"
    echo "To stop services: docker compose down"
    echo ""
}

# Main deployment flow
main() {
    echo ""
    echo "======================================"
    echo "Monitoring System Deployment"
    echo "======================================"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Cleanup existing containers
    cleanup_existing
    
    # Show enabled profiles
    show_profiles
    
    # Check and pull Docker images
    check_images
    
    # Create directories
    create_directories
    
    # Generate configurations
    generate_configs
    
    # Validate configuration
    validate_config
    
    # Deploy services
    deploy_services
    
    # Deploy Portainer
    deploy_portainer
    
    # Import dashboards
    import_dashboards
    
    # Show summary
    show_summary
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"