#!/bin/bash

################################################################################
# Test Profiles Script
# This script shows which profiles are enabled and what services will be deployed
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

# Show profile configuration
show_profile_config() {
    echo ""
    echo "======================================"
    echo "Profile Configuration Test"
    echo "======================================"
    echo ""
    
    # Check basic profiles
    echo "Basic Monitoring (Always Enabled):"
    echo "  ✅ Grafana: ${GRAFANA_IMAGE:-grafana/grafana:10.0.0}"
    echo "  ✅ Prometheus: ${PROMETHEUS_IMAGE:-prom/prometheus:v2.45.0}"
    echo "  ✅ Node Exporter: ${NODE_EXPORTER_IMAGE:-prom/node-exporter:v1.6.0}"
    echo ""
    
    # Check SNMP profile
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        echo "🔹 SNMP Monitoring (ENABLED):"
        echo "  ✅ InfluxDB: ${INFLUXDB_IMAGE:-influxdb:2.7.0}"
        echo "  ✅ Telegraf SNMP: ${TELEGRAF_IMAGE:-telegraf:1.27.0}"
        echo "  📍 SNMP Agents: ${TELEGRAF_SNMP_AGENTS:-Not configured}"
    else
        echo "🔹 SNMP Monitoring (DISABLED)"
    fi
    echo ""
    
    # Check Exec Scripts profile
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        echo "🔹 Custom Scripts (ENABLED):"
        echo "  ✅ Telegraf Exec: ${TELEGRAF_IMAGE:-telegraf:1.27.0}"
        echo "  📍 Scripts Directory: ${TELEGRAF_EXEC_SCRIPTS_PATH:-./exec-scripts}"
    else
        echo "🔹 Custom Scripts (DISABLED)"
    fi
    echo ""
    
    # Check AlertManager profile
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        echo "🔹 AlertManager (ENABLED):"
        echo "  ✅ AlertManager: ${ALERTMANAGER_IMAGE:-prom/alertmanager:v0.25.0}"
        echo "  📧 Email Alerts: ${ALERT_EMAIL_ENABLED:-false}"
        echo "  💬 Slack Alerts: ${ALERT_SLACK_ENABLED:-false}"
    else
        echo "🔹 AlertManager (DISABLED)"
    fi
    echo ""
}

# Show Docker Compose profiles
show_docker_profiles() {
    echo "Docker Compose Profiles:"
    
    local profiles=""
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        profiles="$profiles snmp"
    fi
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        profiles="$profiles exec"
    fi
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        profiles="$profiles alerting"
    fi
    
    if [ -z "$profiles" ]; then
        echo "  📋 No optional profiles (basic monitoring only)"
        echo "  🚀 Command: docker compose up -d"
    else
        echo "  📋 Enabled profiles: $profiles"
        echo "  🚀 Command: docker compose --profile snmp --profile exec --profile alerting up -d"
    fi
    echo ""
}

# Show required images
show_required_images() {
    echo "Required Docker Images:"
    
    # Base images
    echo "  📦 ${GRAFANA_IMAGE:-grafana/grafana:10.0.0}"
    echo "  📦 ${PROMETHEUS_IMAGE:-prom/prometheus:v2.45.0}"
    echo "  📦 ${NODE_EXPORTER_IMAGE:-prom/node-exporter:v1.6.0}"
    
    # Optional images
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        echo "  📦 ${INFLUXDB_IMAGE:-influxdb:2.7.0}"
        echo "  📦 ${TELEGRAF_IMAGE:-telegraf:1.27.0}"
    fi
    
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ] && [ "${ENABLE_SNMP:-false}" != "true" ]; then
        echo "  📦 ${TELEGRAF_IMAGE:-telegraf:1.27.0}"
    fi
    
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        echo "  📦 ${ALERTMANAGER_IMAGE:-prom/alertmanager:v0.25.0}"
    fi
    echo ""
}

# Show service endpoints
show_endpoints() {
    echo "Service Endpoints:"
    echo "  🌐 Grafana: http://localhost:${GRAFANA_PORT:-3000}"
    echo "  📊 Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        echo "  💾 InfluxDB: http://localhost:${INFLUXDB_PORT:-8086}"
    fi
    
    if [ "${ENABLE_ALERTMANAGER:-false}" = "true" ]; then
        echo "  🚨 AlertManager: http://localhost:${ALERTMANAGER_PORT:-9093}"
    fi
    echo ""
}

# Show credentials
show_credentials() {
    echo "Default Credentials:"
    echo "  👤 Grafana Admin: ${GRAFANA_ADMIN_USER:-admin}"
    echo "  🔑 Grafana Password: ${GRAFANA_ADMIN_PASSWORD:-admin}"
    
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        echo "  👤 InfluxDB User: ${INFLUXDB_USERNAME:-admin}"
        echo "  🔑 InfluxDB Password: ${INFLUXDB_PASSWORD:-changeMe}"
        echo "  🏢 InfluxDB Org: ${INFLUXDB_ORG:-my-org}"
        echo "  🪣 InfluxDB Bucket: ${INFLUXDB_BUCKET:-monitoring-data}"
    fi
    echo ""
}

# Test Docker Compose configuration
test_docker_compose() {
    echo "Testing Docker Compose Configuration:"
    
    if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        cd "$PROJECT_ROOT"
        
        # Test basic configuration
        if docker compose config &> /dev/null; then
            log_success "Basic docker-compose.yml is valid"
        else
            log_error "Basic docker-compose.yml has errors"
            return 1
        fi
        
        # Test with profiles
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
        
        if [ -n "$profiles" ]; then
            if docker compose $profiles config &> /dev/null; then
                log_success "Docker Compose with profiles is valid"
            else
                log_error "Docker Compose with profiles has errors"
                return 1
            fi
        fi
    else
        log_error "docker-compose.yml not found"
        return 1
    fi
}

# Main function
main() {
    echo ""
    echo "======================================"
    echo "Profile Configuration Test"
    echo "======================================"
    echo ""
    
    # Load environment variables
    load_env
    
    # Show profile configuration
    show_profile_config
    
    # Show Docker Compose profiles
    show_docker_profiles
    
    # Show required images
    show_required_images
    
    # Show service endpoints
    show_endpoints
    
    # Show credentials
    show_credentials
    
    # Test Docker Compose configuration
    test_docker_compose
    
    echo ""
    log_success "Profile test completed!"
    echo ""
}

# Run main function
main "$@" 