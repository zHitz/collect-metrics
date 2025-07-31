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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and configure it."
    exit 1
fi

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

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    
    # Data directories
    mkdir -p "$PROJECT_ROOT/data"/{influxdb,influxdb-config,grafana,prometheus,alertmanager}
    
    # Config directories
    mkdir -p "$PROJECT_ROOT/configs/prometheus/"{rules,targets}
    mkdir -p "$PROJECT_ROOT/configs/alertmanager"
    
    # Dashboard directories
    mkdir -p "$PROJECT_ROOT/dashboards"/{system,network,custom}
    
    # Scripts directory
    mkdir -p "$PROJECT_ROOT/exec-scripts"
    
    # Backup directory
    if [ "${BACKUP_ENABLED}" = "true" ]; then
        mkdir -p "$PROJECT_ROOT/backups"
    fi
    
    log_success "Directories created successfully"
}

# Generate configuration files
generate_configs() {
    log_info "Generating configuration files..."
    
    # Run configuration script
    "$SCRIPT_DIR/configure.sh"
    
    log_success "Configuration files generated"
}

# Prepare Docker profiles based on enabled modules
prepare_docker_profiles() {
    PROFILES=""
    
    if [ "${ENABLE_SNMP}" = "true" ]; then
        PROFILES="$PROFILES --profile snmp"
        log_info "SNMP monitoring enabled"
    fi
    
    if [ "${ENABLE_EXEC_SCRIPTS}" = "true" ]; then
        PROFILES="$PROFILES --profile exec"
        log_info "Exec scripts monitoring enabled"
    fi
    
    if [ "${ENABLE_ALERTMANAGER}" = "true" ]; then
        PROFILES="$PROFILES --profile alerting"
        log_info "AlertManager enabled"
    fi
    
    echo "$PROFILES"
}

# Deploy services
deploy_services() {
    log_info "Deploying monitoring services..."
    
    cd "$PROJECT_ROOT"
    
    # Get profiles
    PROFILES=$(prepare_docker_profiles)
    
    # Pull latest images
    log_info "Pulling Docker images..."
    docker compose $PROFILES pull
    
    # Start services
    log_info "Starting services..."
    docker compose $PROFILES up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check service status
    docker compose ps
    
    log_success "Services deployed successfully"
}

# Configure Prometheus targets
configure_prometheus_targets() {
    log_info "Configuring Prometheus targets..."
    
    # Create example node exporter targets file
    cat > "$PROJECT_ROOT/configs/prometheus/targets/node-example.yml" <<EOF
# Node Exporter Targets
# Add your remote node exporters here
- targets:
  # - 'server1.example.com:9100'
  # - 'server2.example.com:9100'
  labels:
    job: 'node-exporter-remote'
    environment: 'production'
EOF
    
    log_success "Prometheus targets configured"
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

# Show deployment summary
show_summary() {
    echo ""
    echo "=================================="
    echo "Deployment Summary"
    echo "=================================="
    echo ""
    echo "Services deployed:"
    echo "  - InfluxDB: http://localhost:${INFLUXDB_PORT}"
    echo "  - Grafana: http://localhost:${GRAFANA_PORT}"
    echo "  - Prometheus: http://localhost:${PROMETHEUS_PORT}"
    echo ""
    echo "Credentials:"
    echo "  - Grafana:"
    echo "    Username: ${GRAFANA_ADMIN_USER}"
    echo "    Password: ${GRAFANA_ADMIN_PASSWORD}"
    echo ""
    echo "  - InfluxDB:"
    echo "    Username: ${INFLUXDB_USERNAME}"
    echo "    Password: ${INFLUXDB_PASSWORD}"
    echo "    Organization: ${INFLUXDB_ORG}"
    echo "    Bucket: ${INFLUXDB_BUCKET}"
    echo ""
    
    if [ "${ENABLE_SNMP}" = "true" ]; then
        echo "SNMP Monitoring: ENABLED"
        echo "  Configure devices in .env file"
        echo ""
    fi
    
    if [ "${ENABLE_EXEC_SCRIPTS}" = "true" ]; then
        echo "Custom Scripts: ENABLED"
        echo "  Place scripts in exec-scripts/ directory"
        echo ""
    fi
    
    echo "Next steps:"
    echo "  1. Access Grafana at http://localhost:${GRAFANA_PORT}"
    echo "  2. Configure additional monitoring targets"
    echo "  3. Import or create custom dashboards"
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
    
    # Create directories
    create_directories
    
    # Generate configurations
    generate_configs
    
    # Configure Prometheus targets
    configure_prometheus_targets
    
    # Deploy services
    deploy_services
    
    # Import dashboards
    import_dashboards
    
    # Show summary
    show_summary
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"