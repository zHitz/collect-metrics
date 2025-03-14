#!/bin/bash

# Script tạo file cấu hình Telegraf
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
check_error() { if [ $? -ne 0 ]; then echo -e "\033[0;31mLỗi: $1\033[0m"; exit 1; fi; }
source "$(dirname "$0")/../.env"

log "Tạo file cấu hình Telegraf..."
sudo mkdir -p "$TELEGRAF_CONFIG_DIR"
sudo bash -c "cat > $TELEGRAF_CONFIG_DIR/telegraf.conf" << 'EOL'
[global_tags]

[agent]
  interval = "10s"
  round_interval = true
  flush_interval = "10s"

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "$INFLUXDB_TOKEN"
  organization = "$INFLUXDB_ORG"
  bucket = "$INFLUXDB_BUCKET"
EOL

# Function Configure Telegraf
configure_telegraf() {
    # Thêm các plugin
    IFS=',' read -r -a plugins <<< "$TELEGRAF_PLUGINS"
    for plugin in "${plugins[@]}"; do
        case "$plugin" in
            "cpu")
                echo '[[inputs.cpu]]' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  percpu = true' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  totalcpu = true' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                ;;
            "memory") ... ;;
            "disk") ... ;;
            "snmp")
                log "Plugin SNMP yêu cầu file MIB. Thêm cấu hình mẫu..."
                echo '[[inputs.snmp]]' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo "  agents = [\"udp://$TELEGRAF_SNMP_HOST:161\"]" >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  version = 2' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo "  community = \"$TELEGRAF_SNMP_COMMUNITY\"" >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  timeout = "10s"' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  retries = 2' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  interval = "30s"' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  [[inputs.snmp.field]]' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '    name = "host_desc"' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '    oid = "1.3.6.1.2.1.1.1.0"' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '    is_tag = true' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '  [[inputs.snmp.table]]' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '    name = "net"' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                echo '    oid = "1.3.6.1.2.1.2.2"' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
                ;;
            *) ... ;;
        esac
    done
}

# Tạo config cho Portainer Stack
create_stack_config() {
    log "Tạo cấu hình cho Portainer Stack..."
    
    # Tạo thư mục cho stack
    STACK_DIR="./stacks/monitoring"
    mkdir -p "$STACK_DIR"
    
    # Copy docker-compose.yml
    cp docker-compose.yml "$STACK_DIR/docker-compose.yml"
    
    # Tạo file .env cho stack
    cat > "$STACK_DIR/.env" << EOL
INFLUXDB_VERSION=${INFLUXDB_VERSION}
INFLUXDB_USERNAME=${INFLUXDB_USERNAME}
INFLUXDB_PASSWORD=${INFLUXDB_PASSWORD}
INFLUXDB_ORG=${INFLUXDB_ORG}
INFLUXDB_BUCKET=${INFLUXDB_BUCKET}
INFLUXDB_TOKEN=${INFLUXDB_TOKEN}
TELEGRAF_VERSION=${TELEGRAF_VERSION}
MEMORY_LIMIT=${MEMORY_LIMIT}
CPU_LIMIT=${CPU_LIMIT}
EOL

    # Tạo telegraf.conf trong volume
    docker volume create telegraf_config
    docker run --rm -v telegraf_config:/etc/telegraf alpine:latest mkdir -p /etc/telegraf
    
    # Copy telegraf.conf vào volume
    docker container create --name dummy -v telegraf_config:/etc/telegraf alpine:latest
    docker cp "$TELEGRAF_CONFIG_DIR/telegraf.conf" dummy:/etc/telegraf/
    docker rm dummy

    log "\033[0;32mCấu hình Stack đã được tạo tại $STACK_DIR\033[0m"
}

# Thực thi
if [ "$TELEGRAF_CONFIG_MANUAL" = "YES" ]; then
    log "Bỏ qua cấu hình tự động."
else
    configure_telegraf
    create_stack_config
fi

sudo chmod 644 "$TELEGRAF_CONFIG_DIR/telegraf.conf"

log "\033[0;32mFile cấu hình Telegraf đã tạo tại $TELEGRAF_CONFIG_DIR/telegraf.conf\033[0m"