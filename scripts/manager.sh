#!/bin/bash

################################################################################
# System Manager Script for Monitoring Stack
# Unified management interface for all monitoring components
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Version
VERSION="1.0.0"

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

log_title() {
    echo -e "\n${PURPLE}========== $1 ==========${NC}\n"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -eq 0 ]; then 
        log_error "Please run this script as a regular user, not as root"
        exit 1
    fi
}

# Show header
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         Monitoring System Manager v${VERSION}              ║"
    echo "║                                                           ║"
    echo "║  Unified management for your monitoring infrastructure    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check system status
check_system_status() {
    log_title "System Status"
    
    echo -e "${BLUE}Core Services:${NC}"
    echo "─────────────────────"
    
    # Check each service
    services=("grafana" "prometheus" "node-exporter")
    
    if [ "${ENABLE_INFLUXDB:-false}" = "true" ]; then
        services+=("influxdb")
    fi
    
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        services+=("telegraf-snmp")
    fi
    
    if [ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ]; then
        services+=("telegraf-exec")
    fi
    
    if [ "${ENABLE_ALERTING:-false}" = "true" ]; then
        services+=("alertmanager")
    fi
    
    for service in "${services[@]}"; do
        container_name="${COMPOSE_PROJECT_NAME}-${service}"
        if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
            echo -e "  ✅ ${service}: ${GREEN}Running${NC}"
        else
            echo -e "  ❌ ${service}: ${RED}Stopped${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}Resource Usage:${NC}"
    echo "─────────────────────"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep "${COMPOSE_PROJECT_NAME}" || true
    
    echo ""
    echo -e "${BLUE}Access URLs:${NC}"
    echo "─────────────────────"
    echo -e "  📊 Grafana:      ${GREEN}http://localhost:${GRAFANA_PORT:-3000}${NC}"
    echo -e "  📈 Prometheus:   ${GREEN}http://localhost:${PROMETHEUS_PORT:-9090}${NC}"
    
    if [ "${ENABLE_INFLUXDB:-false}" = "true" ]; then
        echo -e "  💾 InfluxDB:     ${GREEN}http://localhost:${INFLUXDB_PORT:-8086}${NC}"
    fi
    
    if [ "${ENABLE_ALERTING:-false}" = "true" ]; then
        echo -e "  🚨 AlertManager: ${GREEN}http://localhost:${ALERTMANAGER_PORT:-9093}${NC}"
    fi
    
    if [ "${ENABLE_PORTAINER:-false}" = "true" ]; then
        echo -e "  🐳 Portainer:    ${GREEN}http://localhost:${PORTAINER_PORT:-9000}${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Service management menu
service_management() {
    while true; do
        show_header
        log_title "Service Management"
        
        echo "1) Start all services"
        echo "2) Stop all services"
        echo "3) Restart all services"
        echo "4) Restart specific service"
        echo "5) View service logs"
        echo "6) Execute command in service"
        echo "0) Back to main menu"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                log_info "Starting all services..."
                cd "$PROJECT_ROOT"
                docker compose --profile all up -d
                log_success "All services started"
                read -p "Press Enter to continue..."
                ;;
            2)
                log_info "Stopping all services..."
                cd "$PROJECT_ROOT"
                docker compose --profile all down
                log_success "All services stopped"
                read -p "Press Enter to continue..."
                ;;
            3)
                log_info "Restarting all services..."
                cd "$PROJECT_ROOT"
                docker compose --profile all restart
                log_success "All services restarted"
                read -p "Press Enter to continue..."
                ;;
            4)
                echo "Available services:"
                docker compose ps --format "table {{.Service}}" | tail -n +2
                read -p "Enter service name: " service_name
                docker compose restart "$service_name"
                log_success "Service $service_name restarted"
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "Available services:"
                docker compose ps --format "table {{.Service}}" | tail -n +2
                read -p "Enter service name: " service_name
                read -p "Number of lines to show (default 100): " lines
                lines=${lines:-100}
                docker compose logs --tail "$lines" "$service_name"
                read -p "Press Enter to continue..."
                ;;
            6)
                echo "Available services:"
                docker compose ps --format "table {{.Service}}" | tail -n +2
                read -p "Enter service name: " service_name
                read -p "Enter command to execute: " command
                docker compose exec "$service_name" $command
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

# Configuration management
configuration_management() {
    while true; do
        show_header
        log_title "Configuration Management"
        
        echo "1) View current configuration"
        echo "2) Edit environment variables"
        echo "3) Regenerate configurations"
        echo "4) Validate configurations"
        echo "5) Enable/Disable modules"
        echo "6) Update passwords/tokens"
        echo "0) Back to main menu"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                log_title "Current Configuration"
                echo -e "${BLUE}Enabled Modules:${NC}"
                echo "─────────────────────"
                echo -e "  SNMP Monitoring:    ${ENABLE_SNMP:-false}"
                echo -e "  Custom Scripts:     ${ENABLE_EXEC_SCRIPTS:-false}"
                echo -e "  Alerting:          ${ENABLE_ALERTING:-false}"
                echo -e "  Portainer:         ${ENABLE_PORTAINER:-false}"
                echo ""
                echo -e "${BLUE}Key Settings:${NC}"
                echo "─────────────────────"
                echo -e "  Project Name:      ${COMPOSE_PROJECT_NAME}"
                echo -e "  Grafana Port:      ${GRAFANA_PORT:-3000}"
                echo -e "  Prometheus Port:   ${PROMETHEUS_PORT:-9090}"
                echo -e "  Data Retention:    ${PROMETHEUS_RETENTION:-15d}"
                read -p "Press Enter to continue..."
                ;;
            2)
                log_info "Opening environment file in editor..."
                ${EDITOR:-nano} "$PROJECT_ROOT/.env"
                log_warning "Remember to restart services after changes"
                read -p "Press Enter to continue..."
                ;;
            3)
                log_info "Regenerating configurations..."
                bash "$SCRIPT_DIR/configure.sh"
                log_success "Configurations regenerated"
                read -p "Press Enter to continue..."
                ;;
            4)
                log_info "Validating configurations..."
                # Check Prometheus config
                if docker run --rm -v "$PROJECT_ROOT/configs/prometheus:/etc/prometheus:ro" prom/prometheus promtool check config /etc/prometheus/prometheus.yml; then
                    log_success "Prometheus configuration is valid"
                else
                    log_error "Prometheus configuration is invalid"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                show_header
                log_title "Module Management"
                echo "Current module status:"
                echo -e "  1) SNMP Monitoring:    ${ENABLE_SNMP:-false}"
                echo -e "  2) Custom Scripts:     ${ENABLE_EXEC_SCRIPTS:-false}"
                echo -e "  3) Alerting:          ${ENABLE_ALERTING:-false}"
                echo -e "  4) Portainer:         ${ENABLE_PORTAINER:-false}"
                echo ""
                read -p "Enter module number to toggle (0 to cancel): " module
                
                case $module in
                    1)
                        new_value=$([ "${ENABLE_SNMP:-false}" = "true" ] && echo "false" || echo "true")
                        sed -i "s/^ENABLE_SNMP=.*/ENABLE_SNMP=$new_value/" "$PROJECT_ROOT/.env"
                        log_success "SNMP Monitoring set to $new_value"
                        ;;
                    2)
                        new_value=$([ "${ENABLE_EXEC_SCRIPTS:-false}" = "true" ] && echo "false" || echo "true")
                        sed -i "s/^ENABLE_EXEC_SCRIPTS=.*/ENABLE_EXEC_SCRIPTS=$new_value/" "$PROJECT_ROOT/.env"
                        log_success "Custom Scripts set to $new_value"
                        ;;
                    3)
                        new_value=$([ "${ENABLE_ALERTING:-false}" = "true" ] && echo "false" || echo "true")
                        sed -i "s/^ENABLE_ALERTING=.*/ENABLE_ALERTING=$new_value/" "$PROJECT_ROOT/.env"
                        log_success "Alerting set to $new_value"
                        ;;
                    4)
                        new_value=$([ "${ENABLE_PORTAINER:-false}" = "true" ] && echo "false" || echo "true")
                        sed -i "s/^ENABLE_PORTAINER=.*/ENABLE_PORTAINER=$new_value/" "$PROJECT_ROOT/.env"
                        log_success "Portainer set to $new_value"
                        ;;
                esac
                
                log_warning "Remember to restart services for changes to take effect"
                read -p "Press Enter to continue..."
                ;;
            6)
                log_warning "This will regenerate all passwords and tokens!"
                read -p "Are you sure? (yes/no): " confirm
                if [ "$confirm" = "yes" ]; then
                    # Backup current .env
                    cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup.$(date +%Y%m%d-%H%M%S)"
                    
                    # Remove passwords to force regeneration
                    sed -i 's/^INFLUXDB_PASSWORD=.*/INFLUXDB_PASSWORD=/' "$PROJECT_ROOT/.env"
                    sed -i 's/^GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=/' "$PROJECT_ROOT/.env"
                    sed -i 's/^INFLUXDB_TOKEN=.*/INFLUXDB_TOKEN=/' "$PROJECT_ROOT/.env"
                    
                    # Regenerate
                    bash "$SCRIPT_DIR/configure.sh"
                    
                    log_success "New passwords generated. Check .env file"
                    log_warning "You'll need to restart all services"
                fi
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

# Troubleshooting menu
troubleshooting_menu() {
    while true; do
        show_header
        log_title "Troubleshooting"
        
        echo "1) Check and fix permissions"
        echo "2) Test SNMP connectivity"
        echo "3) Test Docker Compose profiles"
        echo "4) View recent errors"
        echo "5) Check disk usage"
        echo "6) Check network connectivity"
        echo "7) Reset service"
        echo "0) Back to main menu"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                log_info "Checking and fixing permissions..."
                bash "$SCRIPT_DIR/troubleshoot/fix-permissions.sh"
                read -p "Press Enter to continue..."
                ;;
            2)
                if [ "${ENABLE_SNMP:-false}" = "true" ]; then
                    bash "$SCRIPT_DIR/troubleshoot/test-snmp.sh"
                else
                    log_warning "SNMP module is not enabled"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "$SCRIPT_DIR/troubleshoot/test-profiles.sh"
                read -p "Press Enter to continue..."
                ;;
            4)
                log_title "Recent Errors (last 50 lines)"
                docker compose logs --tail 50 | grep -E "ERROR|error|Error|FATAL|fatal|Fatal" || echo "No errors found"
                read -p "Press Enter to continue..."
                ;;
            5)
                log_title "Disk Usage"
                echo -e "${BLUE}Project disk usage:${NC}"
                du -sh "$PROJECT_ROOT"/* | sort -hr | head -20
                echo ""
                echo -e "${BLUE}Docker volumes:${NC}"
                docker system df
                read -p "Press Enter to continue..."
                ;;
            6)
                log_title "Network Connectivity"
                echo "Testing connectivity to key services..."
                
                # Test Grafana
                if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${GRAFANA_PORT:-3000}/api/health" | grep -q "200"; then
                    echo -e "  ✅ Grafana: ${GREEN}OK${NC}"
                else
                    echo -e "  ❌ Grafana: ${RED}Failed${NC}"
                fi
                
                # Test Prometheus
                if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PROMETHEUS_PORT:-9090}/-/healthy" | grep -q "200"; then
                    echo -e "  ✅ Prometheus: ${GREEN}OK${NC}"
                else
                    echo -e "  ❌ Prometheus: ${RED}Failed${NC}"
                fi
                
                read -p "Press Enter to continue..."
                ;;
            7)
                echo "Available services:"
                docker compose ps --format "table {{.Service}}" | tail -n +2
                read -p "Enter service name to reset: " service_name
                read -p "This will delete the service data. Are you sure? (yes/no): " confirm
                
                if [ "$confirm" = "yes" ]; then
                    docker compose stop "$service_name"
                    docker compose rm -f "$service_name"
                    # Remove data volume if exists
                    volume_name="${COMPOSE_PROJECT_NAME}_${service_name}_data"
                    docker volume rm "$volume_name" 2>/dev/null || true
                    docker compose up -d "$service_name"
                    log_success "Service $service_name has been reset"
                fi
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

# Backup and restore menu
backup_restore_menu() {
    while true; do
        show_header
        log_title "Backup & Restore"
        
        echo "1) Create full backup"
        echo "2) List available backups"
        echo "3) Restore from backup"
        echo "4) Delete old backups"
        echo "5) Schedule automatic backups"
        echo "0) Back to main menu"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                log_info "Creating backup..."
                bash "$SCRIPT_DIR/backup.sh"
                read -p "Press Enter to continue..."
                ;;
            2)
                log_title "Available Backups"
                backup_dir="$PROJECT_ROOT/${BACKUP_PATH:-./backups}"
                if [ -d "$backup_dir" ]; then
                    ls -lah "$backup_dir" | grep "monitoring-backup" || echo "No backups found"
                else
                    echo "No backup directory found"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                log_warning "Restore functionality not yet implemented"
                log_info "Manual restore steps:"
                echo "1. Stop all services: docker compose down"
                echo "2. Extract backup: tar -xzf backup.tar.gz"
                echo "3. Copy data to appropriate directories"
                echo "4. Start services: docker compose up -d"
                read -p "Press Enter to continue..."
                ;;
            4)
                read -p "Delete backups older than how many days? (default: 30): " days
                days=${days:-30}
                backup_dir="$PROJECT_ROOT/${BACKUP_PATH:-./backups}"
                if [ -d "$backup_dir" ]; then
                    find "$backup_dir" -name "monitoring-backup-*.tar.gz" -mtime +$days -delete
                    log_success "Deleted backups older than $days days"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                log_info "To schedule automatic backups, add this to your crontab:"
                echo ""
                echo "# Daily backup at 2 AM"
                echo "0 2 * * * $SCRIPT_DIR/backup.sh >> /var/log/monitoring-backup.log 2>&1"
                echo ""
                echo "Run: crontab -e"
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

# Data management menu
data_management_menu() {
    while true; do
        show_header
        log_title "Data Management"
        
        echo "1) View data usage statistics"
        echo "2) Clean up old data"
        echo "3) Export metrics data"
        echo "4) Import metrics data"
        echo "5) Optimize database"
        echo "0) Back to main menu"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                log_title "Data Usage Statistics"
                echo -e "${BLUE}Data directories:${NC}"
                echo "─────────────────────"
                
                # Check each data directory
                for dir in grafana prometheus influxdb; do
                    data_path="$PROJECT_ROOT/data/$dir"
                    if [ -d "$data_path" ]; then
                        size=$(du -sh "$data_path" 2>/dev/null | cut -f1)
                        echo -e "  $dir: ${GREEN}$size${NC}"
                    fi
                done
                
                echo ""
                echo -e "${BLUE}Database metrics:${NC}"
                echo "─────────────────────"
                
                # Prometheus metrics
                if docker compose ps prometheus | grep -q "running"; then
                    echo "  Prometheus:"
                    curl -s "http://localhost:${PROMETHEUS_PORT:-9090}/api/v1/query?query=prometheus_tsdb_symbol_table_size_bytes" | jq -r '.data.result[0].value[1]' | xargs -I {} echo "    Symbol table: {} bytes"
                fi
                
                read -p "Press Enter to continue..."
                ;;
            2)
                log_warning "This will remove old metrics data!"
                read -p "Remove data older than how many days? (default: 30): " days
                days=${days:-30}
                
                read -p "Are you sure? (yes/no): " confirm
                if [ "$confirm" = "yes" ]; then
                    # For Prometheus (if using local storage)
                    log_info "Prometheus uses retention policy, no manual cleanup needed"
                    
                    # For InfluxDB
                    if [ "${ENABLE_INFLUXDB:-false}" = "true" ] && docker compose ps influxdb | grep -q "running"; then
                        log_info "Cleaning InfluxDB data older than $days days..."
                        docker compose exec influxdb influx delete \
                            --bucket "${INFLUXDB_BUCKET:-metrics}" \
                            --start "1970-01-01T00:00:00Z" \
                            --stop "$(date -d "$days days ago" -Iseconds)" \
                            --org "${INFLUXDB_ORG:-monitoring}"
                    fi
                    
                    log_success "Cleanup completed"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                log_title "Export Metrics Data"
                read -p "Export format (prometheus/influxdb): " format
                
                case $format in
                    prometheus)
                        timestamp=$(date +%Y%m%d-%H%M%S)
                        output_file="$PROJECT_ROOT/prometheus-export-$timestamp.tar"
                        log_info "Creating Prometheus snapshot..."
                        
                        # Create snapshot via API
                        curl -XPOST "http://localhost:${PROMETHEUS_PORT:-9090}/api/v1/admin/tsdb/snapshot"
                        
                        # Find and copy snapshot
                        snapshot_dir=$(docker compose exec prometheus find /prometheus/snapshots -name "*.tar" -type f | head -1)
                        if [ -n "$snapshot_dir" ]; then
                            docker compose cp "prometheus:$snapshot_dir" "$output_file"
                            log_success "Export saved to: $output_file"
                        else
                            log_error "Failed to create snapshot"
                        fi
                        ;;
                    influxdb)
                        if [ "${ENABLE_INFLUXDB:-false}" = "true" ]; then
                            timestamp=$(date +%Y%m%d-%H%M%S)
                            output_dir="$PROJECT_ROOT/influxdb-export-$timestamp"
                            mkdir -p "$output_dir"
                            
                            log_info "Exporting InfluxDB data..."
                            docker compose exec influxdb influx backup "$output_dir" \
                                --bucket "${INFLUXDB_BUCKET:-metrics}" \
                                --org "${INFLUXDB_ORG:-monitoring}"
                            
                            log_success "Export saved to: $output_dir"
                        else
                            log_error "InfluxDB is not enabled"
                        fi
                        ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            4)
                log_warning "Import functionality requires manual steps"
                echo "For Prometheus: Use remote write or federation"
                echo "For InfluxDB: Use influx restore command"
                read -p "Press Enter to continue..."
                ;;
            5)
                log_info "Optimizing databases..."
                
                # Prometheus compaction
                if docker compose ps prometheus | grep -q "running"; then
                    log_info "Triggering Prometheus compaction..."
                    curl -XPOST "http://localhost:${PROMETHEUS_PORT:-9090}/api/v1/admin/tsdb/compact"
                fi
                
                log_success "Optimization completed"
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

# Quick actions menu
quick_actions_menu() {
    while true; do
        show_header
        log_title "Quick Actions"
        
        echo "1) Health check all services"
        echo "2) Update all Docker images"
        echo "3) Generate system report"
        echo "4) Open Grafana in browser"
        echo "5) Test all endpoints"
        echo "6) Clear all logs"
        echo "0) Back to main menu"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                log_title "Health Check Results"
                
                # Define health check endpoints
                declare -A health_checks=(
                    ["Grafana"]="http://localhost:${GRAFANA_PORT:-3000}/api/health"
                    ["Prometheus"]="http://localhost:${PROMETHEUS_PORT:-9090}/-/healthy"
                    ["Node Exporter"]="http://localhost:${NODE_EXPORTER_PORT:-9100}/metrics"
                )
                
                if [ "${ENABLE_INFLUXDB:-false}" = "true" ]; then
                    health_checks["InfluxDB"]="http://localhost:${INFLUXDB_PORT:-8086}/health"
                fi
                
                if [ "${ENABLE_ALERTING:-false}" = "true" ]; then
                    health_checks["AlertManager"]="http://localhost:${ALERTMANAGER_PORT:-9093}/-/healthy"
                fi
                
                # Check each endpoint
                for service in "${!health_checks[@]}"; do
                    url="${health_checks[$service]}"
                    if curl -s -f -o /dev/null "$url"; then
                        echo -e "  ✅ $service: ${GREEN}Healthy${NC}"
                    else
                        echo -e "  ❌ $service: ${RED}Unhealthy${NC}"
                    fi
                done
                
                read -p "Press Enter to continue..."
                ;;
            2)
                log_info "Updating all Docker images..."
                cd "$PROJECT_ROOT"
                docker compose pull
                log_success "Images updated. Restart services to apply changes."
                read -p "Press Enter to continue..."
                ;;
            3)
                log_info "Generating system report..."
                report_file="$PROJECT_ROOT/system-report-$(date +%Y%m%d-%H%M%S).txt"
                
                {
                    echo "=== Monitoring System Report ==="
                    echo "Generated: $(date)"
                    echo ""
                    echo "=== System Information ==="
                    uname -a
                    echo ""
                    echo "=== Docker Version ==="
                    docker version
                    echo ""
                    echo "=== Service Status ==="
                    docker compose ps
                    echo ""
                    echo "=== Resource Usage ==="
                    docker stats --no-stream
                    echo ""
                    echo "=== Disk Usage ==="
                    df -h
                    echo ""
                    echo "=== Recent Logs ==="
                    docker compose logs --tail 50
                } > "$report_file"
                
                log_success "Report saved to: $report_file"
                read -p "Press Enter to continue..."
                ;;
            4)
                log_info "Opening Grafana in browser..."
                url="http://localhost:${GRAFANA_PORT:-3000}"
                
                # Try different commands to open browser
                if command -v xdg-open &> /dev/null; then
                    xdg-open "$url"
                elif command -v open &> /dev/null; then
                    open "$url"
                else
                    echo "Please open manually: $url"
                fi
                
                echo "Default credentials: ${GRAFANA_ADMIN_USER:-admin} / check .env for password"
                read -p "Press Enter to continue..."
                ;;
            5)
                log_title "Testing All Endpoints"
                
                endpoints=(
                    "Grafana|http://localhost:${GRAFANA_PORT:-3000}"
                    "Prometheus|http://localhost:${PROMETHEUS_PORT:-9090}"
                    "Node Exporter|http://localhost:${NODE_EXPORTER_PORT:-9100}"
                )
                
                if [ "${ENABLE_INFLUXDB:-false}" = "true" ]; then
                    endpoints+=("InfluxDB|http://localhost:${INFLUXDB_PORT:-8086}")
                fi
                
                for endpoint in "${endpoints[@]}"; do
                    IFS='|' read -r name url <<< "$endpoint"
                    response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
                    if [ "$response" = "200" ] || [ "$response" = "204" ]; then
                        echo -e "  ✅ $name ($url): ${GREEN}$response OK${NC}"
                    else
                        echo -e "  ❌ $name ($url): ${RED}$response FAILED${NC}"
                    fi
                done
                
                read -p "Press Enter to continue..."
                ;;
            6)
                log_warning "This will clear all container logs!"
                read -p "Are you sure? (yes/no): " confirm
                
                if [ "$confirm" = "yes" ]; then
                    # Get all container IDs
                    containers=$(docker compose ps -q)
                    
                    for container in $containers; do
                        log_file=$(docker inspect --format='{{.LogPath}}' "$container")
                        if [ -n "$log_file" ]; then
                            sudo truncate -s 0 "$log_file" 2>/dev/null || log_warning "Could not clear log for container $container"
                        fi
                    done
                    
                    log_success "Logs cleared"
                fi
                read -p "Press Enter to continue..."
                ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

# Main menu
main_menu() {
    while true; do
        show_header
        
        echo "📊 Main Menu"
        echo "════════════════════════════════════════"
        echo ""
        echo "1) 📈 System Status Overview"
        echo "2) 🔧 Service Management"
        echo "3) ⚙️  Configuration Management"
        echo "4) 🔍 Troubleshooting"
        echo "5) 💾 Backup & Restore"
        echo "6) 📊 Data Management"
        echo "7) ⚡ Quick Actions"
        echo ""
        echo "8) 📚 View Documentation"
        echo "9) ℹ️  About"
        echo "0) 🚪 Exit"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1) check_system_status ;;
            2) service_management ;;
            3) configuration_management ;;
            4) troubleshooting_menu ;;
            5) backup_restore_menu ;;
            6) data_management_menu ;;
            7) quick_actions_menu ;;
            8)
                log_info "Opening documentation..."
                if [ -f "$PROJECT_ROOT/README.md" ]; then
                    ${PAGER:-less} "$PROJECT_ROOT/README.md"
                else
                    log_error "README.md not found"
                fi
                ;;
            9)
                show_header
                log_title "About"
                echo "Monitoring System Manager v${VERSION}"
                echo ""
                echo "A comprehensive management interface for your"
                echo "monitoring infrastructure based on:"
                echo ""
                echo "  • Prometheus - Metrics collection"
                echo "  • Grafana - Visualization"
                echo "  • InfluxDB - Time series database"
                echo "  • Telegraf - Data collection"
                echo "  • AlertManager - Alert handling"
                echo ""
                echo "Project: https://github.com/your-org/collect-metrics"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                echo ""
                log_success "Thank you for using Monitoring System Manager!"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Main execution
main() {
    check_root
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please run install-docker.sh first."
        exit 1
    fi
    
    # Check if docker-compose.yml exists
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found. Are you in the correct directory?"
        exit 1
    fi
    
    # Start main menu
    main_menu
}

# Run main function
main "$@"