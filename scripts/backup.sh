#!/bin/bash

################################################################################
# Backup Script for Monitoring System
# Creates backups of data and configurations
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

# Backup configuration
BACKUP_PATH="${BACKUP_PATH:-./backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="monitoring-backup-$TIMESTAMP"
BACKUP_DIR="$PROJECT_ROOT/$BACKUP_PATH/$BACKUP_NAME"

# Create backup directory
create_backup_dir() {
    log_info "Creating backup directory..."
    mkdir -p "$BACKUP_DIR"/{data,configs,dashboards,scripts}
}

# Backup configurations
backup_configs() {
    log_info "Backing up configurations..."
    
    # Copy environment file (remove sensitive data)
    grep -v -E 'PASSWORD|TOKEN' "$PROJECT_ROOT/.env" > "$BACKUP_DIR/.env.backup" || true
    
    # Copy all configuration files
    cp -r "$PROJECT_ROOT/configs" "$BACKUP_DIR/"
    
    # Copy docker-compose.yml
    cp "$PROJECT_ROOT/docker-compose.yml" "$BACKUP_DIR/"
    
    log_success "Configurations backed up"
}

# Backup InfluxDB data
backup_influxdb() {
    log_info "Backing up InfluxDB data..."
    
    if docker compose ps influxdb | grep -q "running"; then
        # Create backup using InfluxDB CLI
        docker compose exec -T influxdb influx backup /tmp/influx-backup \
            --org "${INFLUXDB_ORG}" \
            --token "${INFLUXDB_TOKEN}" 2>/dev/null || {
            log_warning "Failed to backup InfluxDB using CLI, trying volume copy..."
            
            # Fallback: Copy volume data
            sudo cp -r "$PROJECT_ROOT/data/influxdb" "$BACKUP_DIR/data/" || {
                log_error "Failed to backup InfluxDB data"
                return 1
            }
        }
        
        # Copy backup from container
        docker cp monitoring-influxdb:/tmp/influx-backup "$BACKUP_DIR/data/influxdb" 2>/dev/null || true
        
        # Clean up
        docker compose exec -T influxdb rm -rf /tmp/influx-backup 2>/dev/null || true
        
        log_success "InfluxDB data backed up"
    else
        log_warning "InfluxDB is not running, skipping data backup"
    fi
}

# Backup Prometheus data
backup_prometheus() {
    log_info "Backing up Prometheus data..."
    
    if [ -d "$PROJECT_ROOT/data/prometheus" ]; then
        # Create snapshot
        if docker compose ps prometheus | grep -q "running"; then
            # Trigger snapshot via API
            SNAPSHOT_RESULT=$(curl -s -X POST http://localhost:${PROMETHEUS_PORT}/api/v1/admin/tsdb/snapshot)
            SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESULT" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
            
            if [ ! -z "$SNAPSHOT_NAME" ]; then
                # Copy snapshot
                sudo cp -r "$PROJECT_ROOT/data/prometheus/snapshots/$SNAPSHOT_NAME" \
                    "$BACKUP_DIR/data/prometheus-snapshot" || true
                    
                # Clean up snapshot
                sudo rm -rf "$PROJECT_ROOT/data/prometheus/snapshots/$SNAPSHOT_NAME"
                
                log_success "Prometheus snapshot created and backed up"
            else
                log_warning "Failed to create Prometheus snapshot, copying data directly"
                sudo cp -r "$PROJECT_ROOT/data/prometheus" "$BACKUP_DIR/data/"
            fi
        else
            # Just copy the data directory
            sudo cp -r "$PROJECT_ROOT/data/prometheus" "$BACKUP_DIR/data/"
        fi
    else
        log_warning "Prometheus data directory not found"
    fi
}

# Backup Grafana data
backup_grafana() {
    log_info "Backing up Grafana data..."
    
    if [ -d "$PROJECT_ROOT/data/grafana" ]; then
        sudo cp -r "$PROJECT_ROOT/data/grafana" "$BACKUP_DIR/data/"
        log_success "Grafana data backed up"
    else
        log_warning "Grafana data directory not found"
    fi
    
    # Backup dashboards
    if [ -d "$PROJECT_ROOT/dashboards" ]; then
        cp -r "$PROJECT_ROOT/dashboards" "$BACKUP_DIR/"
        log_success "Dashboards backed up"
    fi
}

# Backup custom scripts
backup_scripts() {
    log_info "Backing up custom scripts..."
    
    if [ -d "$PROJECT_ROOT/exec-scripts" ]; then
        # Exclude examples directory
        rsync -av --exclude='examples/' "$PROJECT_ROOT/exec-scripts/" "$BACKUP_DIR/scripts/exec-scripts/"
        log_success "Custom scripts backed up"
    fi
}

# Compress backup
compress_backup() {
    log_info "Compressing backup..."
    
    cd "$PROJECT_ROOT/$BACKUP_PATH"
    tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
    
    # Remove uncompressed backup
    rm -rf "$BACKUP_NAME"
    
    # Calculate size
    BACKUP_SIZE=$(du -h "$BACKUP_NAME.tar.gz" | cut -f1)
    log_success "Backup compressed: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
}

# Clean old backups
clean_old_backups() {
    log_info "Cleaning old backups (retention: $BACKUP_RETENTION_DAYS days)..."
    
    find "$PROJECT_ROOT/$BACKUP_PATH" -name "monitoring-backup-*.tar.gz" \
        -type f -mtime +$BACKUP_RETENTION_DAYS -delete
    
    REMAINING_BACKUPS=$(find "$PROJECT_ROOT/$BACKUP_PATH" -name "monitoring-backup-*.tar.gz" | wc -l)
    log_success "Old backups cleaned. Remaining backups: $REMAINING_BACKUPS"
}

# Verify backup
verify_backup() {
    log_info "Verifying backup..."
    
    if tar -tzf "$PROJECT_ROOT/$BACKUP_PATH/$BACKUP_NAME.tar.gz" > /dev/null 2>&1; then
        log_success "Backup verification passed"
        return 0
    else
        log_error "Backup verification failed!"
        return 1
    fi
}

# Main backup process
main() {
    echo ""
    echo "======================================"
    echo "Monitoring System Backup"
    echo "======================================"
    echo ""
    
    # Check if backup is enabled
    if [ "${BACKUP_ENABLED:-false}" = "false" ]; then
        log_warning "Backups are disabled. Set BACKUP_ENABLED=true in .env to enable."
        log_info "Running manual backup anyway..."
    fi
    
    # Create backup directory
    create_backup_dir
    
    # Perform backups
    backup_configs
    backup_influxdb
    backup_prometheus
    backup_grafana
    backup_scripts
    
    # Compress backup
    compress_backup
    
    # Verify backup
    verify_backup || {
        log_error "Backup verification failed!"
        exit 1
    }
    
    # Clean old backups
    clean_old_backups
    
    echo ""
    log_success "Backup completed successfully!"
    log_info "Backup location: $PROJECT_ROOT/$BACKUP_PATH/$BACKUP_NAME.tar.gz"
    echo ""
}

# Run main function
main "$@"