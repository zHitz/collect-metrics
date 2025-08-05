#!/bin/bash

################################################################################
# Configuration Generation Script
# Generates and validates configuration files
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Generate random password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Generate InfluxDB token
generate_token() {
    openssl rand -hex 32
}

# Check and update .env file
check_env_file() {
    log_info "Checking environment configuration..."

    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        log_warning ".env file not found. Creating from template..."
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
    fi

    # Source environment variables before generating passwords
    set -a
    source "$PROJECT_ROOT/.env"
    set +a

    # Only generate and update passwords/tokens if they are empty or default
    update_env=false

    # Check and generate INFLUXDB_PASSWORD
    if [ -z "${INFLUXDB_PASSWORD:-}" ] || [[ "$INFLUXDB_PASSWORD" == "changeMe" ]]; then
        INFLUX_PASS=$(generate_password 20)
        sed -i "s/^INFLUXDB_PASSWORD=.*/INFLUXDB_PASSWORD=$INFLUX_PASS/" "$PROJECT_ROOT/.env"
        echo "INFLUX_PASS: $INFLUX_PASS"
        update_env=true
    fi

    # Check and generate GRAFANA_ADMIN_PASSWORD
    if [ -z "${GRAFANA_ADMIN_PASSWORD:-}" ] || [[ "$GRAFANA_ADMIN_PASSWORD" == "admin" ]]; then
        GRAFANA_PASS=$(generate_password 20)
        sed -i "s/^GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASS/" "$PROJECT_ROOT/.env"
        echo "GRAFANA_PASS: $GRAFANA_PASS"
        update_env=true
    fi

    # Check and generate INFLUXDB_TOKEN
    if [ -z "${INFLUXDB_TOKEN:-}" ] || [[ "$INFLUXDB_TOKEN" == "my-super-secret-auth-token" ]]; then
        echo "Generating INFLUXDB_TOKEN"
        INFLUX_TOKEN=$(generate_token)
        sed -i "s/^INFLUXDB_TOKEN=.*/INFLUXDB_TOKEN=$INFLUX_TOKEN/" "$PROJECT_ROOT/.env"
        echo "INFLUX_TOKEN: $INFLUX_TOKEN"
        update_env=true
    fi

    if [ "$update_env" = true ]; then
        log_success "Generated and updated secure passwords and tokens in .env"
    else
        log_info "Passwords and tokens already set in .env, not regenerating."
    fi

    # Re-source environment variables after possible update
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
}

# Process Telegraf SNMP configuration
configure_telegraf_snmp() {
    if [ "${ENABLE_SNMP}" = "true" ]; then
        log_info "Configuring Telegraf SNMP..."

        TEMPLATE="$PROJECT_ROOT/configs/telegraf/telegraf.conf.template"
        OUTPUT="$PROJECT_ROOT/configs/telegraf/telegraf.conf"

        if [ ! -f "$TEMPLATE" ]; then
            log_error "TELEGRAF config template not found"
            return 1
        fi

        # Copy template
        cp "$TEMPLATE" "$OUTPUT"
        log_info "Copied template to $OUTPUT"

        # === Xử lý SNMP agents ===
        if [ -z "${TELEGRAF_SNMP_AGENTS:-}" ]; then
            log_warning "TELEGRAF_SNMP_AGENTS not set, using default"
            TELEGRAF_SNMP_AGENTS="router1:192.168.1.1:161:public,switch1:192.168.1.2:161:public"
        fi

        # Parse agents
        AGENTS_ARRAY=()
        IFS=',' read -ra AGENTS <<< "$TELEGRAF_SNMP_AGENTS"
        for agent in "${AGENTS[@]}"; do
            IFS=':' read -ra PARTS <<< "$agent"
            if [ ${#PARTS[@]} -eq 4 ]; then
                AGENTS_ARRAY+=("\"${PARTS[1]}:${PARTS[2]}\"")
                log_info "Added SNMP agent: ${PARTS[1]}:${PARTS[2]} (${PARTS[0]})"
            else
                log_warning "Invalid SNMP agent format: $agent"
            fi
        done

        AGENTS_STRING=$(IFS=','; echo "${AGENTS_ARRAY[*]}")
        sed -i "s|agents = \[.*\]|agents = [$AGENTS_STRING]|" "$OUTPUT"

        # === Thay các biến SNMP khác ===
        sed -i "s|\${TELEGRAF_SNMP_VERSION:-2}|${TELEGRAF_SNMP_VERSION:-2}|" "$OUTPUT"
        sed -i "s|\${TELEGRAF_SNMP_COMMUNITY:-public}|${TELEGRAF_SNMP_COMMUNITY:-public}|" "$OUTPUT"
        sed -i "s|\${TELEGRAF_SNMP_INTERVAL:-30s}|${TELEGRAF_SNMP_INTERVAL:-30s}|" "$OUTPUT"
        sed -i "s|\${TELEGRAF_DEBUG:-false}|${TELEGRAF_DEBUG:-false}|" "$OUTPUT"
        sed -i "s|\${TELEGRAF_QUIET:-false}|${TELEGRAF_QUIET:-false}|" "$OUTPUT"

        log_success "Telegraf SNMP configuration completed"
    else
        log_info "SNMP monitoring disabled"
    fi
}


# Configure Prometheus targets
configure_prometheus_targets() {
    log_info "Configuring Prometheus targets..."
    
    # Parse node exporter targets
    if [ ! -z "${NODE_EXPORTER_TARGETS}" ]; then
        # Create targets file
        cat > "$PROJECT_ROOT/configs/prometheus/targets/node-exporters.yml" <<EOF
# Auto-generated Node Exporter targets
- targets:
EOF
        
        # Add each target
        IFS=',' read -ra TARGETS <<< "$NODE_EXPORTER_TARGETS"
        for target in "${TARGETS[@]}"; do
            echo "    - '$target'" >> "$PROJECT_ROOT/configs/prometheus/targets/node-exporters.yml"
        done
        
        cat >> "$PROJECT_ROOT/configs/prometheus/targets/node-exporters.yml" <<EOF
  labels:
    job: 'node-exporter-remote'
    environment: 'production'
EOF
        
        log_success "Prometheus targets configured"
    fi
}

# Validate Grafana datasource configuration
validate_grafana_config() {
    log_info "Validating Grafana configuration..."

    TEMPLATE_FILE="$PROJECT_ROOT/configs/grafana/provisioning/datasources/datasources.yml.template"
    OUTPUT_FILE="$PROJECT_ROOT/configs/grafana/provisioning/datasources/datasources.yml"

    if [ -f "$TEMPLATE_FILE" ]; then
        # Replace environment variables in template and output to final config
        envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
        log_success "Grafana datasources configured from template"
    else
        log_error "Template file not found: $TEMPLATE_FILE"
    fi
}

# Create AlertManager configuration if enabled
configure_alertmanager() {
    if [ "${ENABLE_ALERTMANAGER}" = "true" ]; then
        log_info "Configuring AlertManager..."
        
        mkdir -p "$PROJECT_ROOT/configs/alertmanager"
        
        cat > "$PROJECT_ROOT/configs/alertmanager/alertmanager.yml" <<EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'critical'
      continue: true

receivers:
  - name: 'default'
    # Default receiver (logs only)

  - name: 'critical'
EOF
        
        # Add email configuration if enabled
        if [ "${ALERT_EMAIL_ENABLED}" = "true" ]; then
            cat >> "$PROJECT_ROOT/configs/alertmanager/alertmanager.yml" <<EOF
    email_configs:
      - to: '${ALERT_EMAIL_TO}'
        from: '${ALERT_EMAIL_FROM}'
        smarthost: '${ALERT_EMAIL_HOST}:${ALERT_EMAIL_PORT}'
        auth_username: '${ALERT_EMAIL_USER}'
        auth_password: '${ALERT_EMAIL_PASSWORD}'
        headers:
          Subject: '[ALERT] {{ .GroupLabels.alertname }}'
EOF
        fi
        
        # Add Slack configuration if enabled
        if [ "${ALERT_SLACK_ENABLED}" = "true" ]; then
            cat >> "$PROJECT_ROOT/configs/alertmanager/alertmanager.yml" <<EOF
    slack_configs:
      - api_url: '${ALERT_SLACK_WEBHOOK}'
        channel: '${ALERT_SLACK_CHANNEL}'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
EOF
        fi
        
        log_success "AlertManager configured"
    fi
}

# Create sample Prometheus rules
create_prometheus_rules() {
    log_info "Creating Prometheus alert rules..."
    
    mkdir -p "$PROJECT_ROOT/configs/prometheus/rules"
    
    cat > "$PROJECT_ROOT/configs/prometheus/rules/node-alerts.yml" <<EOF
groups:
  - name: node_alerts
    interval: 30s
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ \$labels.instance }}"
          description: "CPU usage is above 80% (current value: {{ \$value }}%)"
      
      # High memory usage
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ \$labels.instance }}"
          description: "Memory usage is above 85% (current value: {{ \$value }}%)"
      
      # Disk space low
      - alert: LowDiskSpace
        expr: (1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"} / node_filesystem_size_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ \$labels.instance }}"
          description: "Disk usage is above 90% on {{ \$labels.device }} (current value: {{ \$value }}%)"
      
      # Node down
      - alert: NodeDown
        expr: up{job="node-exporter-local"} == 0 or up{job="node-exporter-remote"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ \$labels.instance }} is down"
          description: "Node exporter on {{ \$labels.instance }} has been down for more than 2 minutes"
EOF
    
    log_success "Prometheus alert rules created"
}

# Main configuration flow
main() {
    echo ""
    echo "======================================"
    echo "Configuration Generator"
    echo "======================================"
    echo ""
    
    # Check environment file
    check_env_file
    
    # Configure components based on settings

    # Telegraf
    configure_telegraf_snmp
    configure_prometheus_targets
    validate_grafana_config
    configure_alertmanager
    create_prometheus_rules
    
    # Set permissions
    chmod +x "$PROJECT_ROOT/scripts"/*.sh
    chmod 600 "$PROJECT_ROOT/.env"
    
    log_success "Configuration generation completed!"
}

# Run main function
main "$@"