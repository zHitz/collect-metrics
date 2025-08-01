#!/bin/bash

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found in $PROJECT_ROOT${NC}"
    exit 1
fi

set -a
source "$PROJECT_ROOT/.env"
set +a

# Set project name for Portainer stack
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-monitoring}-portainer"
COMPOSE_FILE="$SCRIPT_DIR/portainer-compose.yml"

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

# Show usage
show_usage() {
    echo "Portainer Stack Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     - Start Portainer stack"
    echo "  stop      - Stop Portainer stack"
    echo "  restart   - Restart Portainer stack"
    echo "  status    - Show stack status"
    echo "  logs      - Show logs"
    echo "  logs-f    - Follow logs"
    echo "  update    - Update Portainer image and restart"
    echo "  backup    - Backup Portainer data"
    echo "  restore   - Restore Portainer data"
    echo "  clean     - Remove stack and volumes (DANGEROUS!)"
    echo "  help      - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs-f"
    echo "  $0 status"
}

# Start Portainer
start_portainer() {
    log_info "Starting Portainer stack..."
    cd "$SCRIPT_DIR"
    mkdir -p "./data"
    
    docker compose -f "$COMPOSE_FILE" up -d
    
    if [ $? -eq 0 ]; then
        log_success "Portainer started successfully!"
        log_info "Access Portainer at: https://localhost:${PORTAINER_PORT:-9000}"
        log_info "Stack name: $COMPOSE_PROJECT_NAME"
    else
        log_error "Failed to start Portainer!"
        exit 1
    fi
}

# Stop Portainer
stop_portainer() {
    log_info "Stopping Portainer stack..."
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" down
    
    if [ $? -eq 0 ]; then
        log_success "Portainer stopped successfully!"
    else
        log_error "Failed to stop Portainer!"
        exit 1
    fi
}

# Restart Portainer
restart_portainer() {
    log_info "Restarting Portainer stack..."
    stop_portainer
    sleep 2
    start_portainer
}

# Show status
show_status() {
    log_info "Portainer stack status:"
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" ps
}

# Show logs
show_logs() {
    log_info "Showing Portainer logs..."
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" logs
}

# Follow logs
follow_logs() {
    log_info "Following Portainer logs (Ctrl+C to stop)..."
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" logs -f
}

# Update Portainer
update_portainer() {
    log_info "Updating Portainer..."
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" pull
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate
    
    if [ $? -eq 0 ]; then
        log_success "Portainer updated successfully!"
    else
        log_error "Failed to update Portainer!"
        exit 1
    fi
}

# Backup Portainer data
backup_portainer() {
    log_info "Backing up Portainer data..."
    cd "$SCRIPT_DIR"
    
    BACKUP_DIR="$PROJECT_ROOT/backups/portainer"
    BACKUP_FILE="portainer-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    docker compose -f "$COMPOSE_FILE" stop portainer
    
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$SCRIPT_DIR" data/
    
    docker compose -f "$COMPOSE_FILE" start portainer
    
    if [ $? -eq 0 ]; then
        log_success "Backup created: $BACKUP_DIR/$BACKUP_FILE"
    else
        log_error "Failed to create backup!"
        exit 1
    fi
}

# Restore Portainer data
restore_portainer() {
    if [ -z "$1" ]; then
        log_error "Please specify backup file to restore"
        echo "Usage: $0 restore <backup-file>"
        exit 1
    fi
    
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    log_warning "This will overwrite current Portainer data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Restoring Portainer data from $BACKUP_FILE..."
    cd "$SCRIPT_DIR"
    
    docker compose -f "$COMPOSE_FILE" stop portainer
    
    rm -rf data/
    tar -xzf "$BACKUP_FILE" -C "$SCRIPT_DIR"
    
    docker compose -f "$COMPOSE_FILE" start portainer
    
    if [ $? -eq 0 ]; then
        log_success "Portainer data restored successfully!"
    else
        log_error "Failed to restore Portainer data!"
        exit 1
    fi
}

# Clean Portainer
clean_portainer() {
    log_warning "This will remove Portainer stack and ALL data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Clean cancelled"
        exit 0
    fi
    
    log_info "Cleaning Portainer stack..."
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans
    
    if [ $? -eq 0 ]; then
        log_success "Portainer stack cleaned successfully!"
    else
        log_error "Failed to clean Portainer stack!"
        exit 1
    fi
}

# Main script
case "${1:-help}" in
    start)
        start_portainer
        ;;
    stop)
        stop_portainer
        ;;
    restart)
        restart_portainer
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    logs-f)
        follow_logs
        ;;
    update)
        update_portainer
        ;;
    backup)
        backup_portainer
        ;;
    restore)
        restore_portainer "$2"
        ;;
    clean)
        clean_portainer
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac 