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
            echo '  agents = ["udp://172.18.10.2:161"]' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
            echo '  version = 2' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
            echo '  community = "123qwe!@#"' >> "$TELEGRAF_CONFIG_DIR/telegraf.conf"
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
sudo chmod 644 "$TELEGRAF_CONFIG_DIR/telegraf.conf"

# Tải file MIB nếu dùng SNMP
if [[ "$TELEGRAF_PLUGINS" =~ "snmp" ]]; then
    log "Tải file MIB cho SNMP từ GitHub..."
    MIB_DIR="$(dirname "$0")/../mibs"
    sudo mkdir -p "$MIB_DIR"
    sudo wget -O "$MIB_DIR/IF-MIB.txt" "https://raw.githubusercontent.com/net-snmp/net-snmp/master/mibs/IF-MIB.txt"
    sudo wget -O "$MIB_DIR/SNMPv2-MIB.txt" "https://raw.githubusercontent.com/net-snmp/net-snmp/master/mibs/SNMPv2-MIB.txt"
    sudo chmod 644 "$MIB_DIR"/*.txt
    if [ ! -f "$MIB_DIR/IF-MIB.txt" ] || [ ! -f "$MIB_DIR/SNMPv2-MIB.txt" ]; then
        log "\033[0;31mLỗi: File MIB không tải được. Vui lòng tải thủ công.\033[0m"
        exit 1
    fi
    check_error "Tải file MIB"
fi

log "\033[0;32mFile cấu hình Telegraf đã tạo tại $TELEGRAF_CONFIG_DIR/telegraf.conf\033[0m"