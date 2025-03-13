#!/bin/bash

# Script kiểm tra Telegraf
# Ngày: 12/03/2025

# --- Màu sắc cho output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# --- Hàm ghi log ---
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# --- Hàm kiểm tra lỗi ---
check_error() {
    if [ $? -ne 0 ]; then
        log "${RED}Lỗi: $1${NC}"
    else
        log "${GREEN}Thành công: $1${NC}"
    fi
}

log "Bắt đầu kiểm tra Telegraf..."

# 1. Test Output của Telegraf
log "Kiểm tra output của Telegraf với SNMP..."
docker exec telegraf telegraf --test --input-filter=snmp
check_error "Lấy dữ liệu SNMP từ Telegraf"

# 2. Kiểm tra SNMP trên thiết bị
log "Kiểm tra SNMP trên thiết bị 172.18.10.5..."
snmpwalk -v 2c -c hissc 172.18.10.5
check_error "Phản hồi SNMP từ thiết bị"

# 3. Kiểm tra log Telegraf
log "Kiểm tra log Telegraf..."
docker logs telegraf | tail -20
check_error "Log Telegraf không có lỗi"

# 4. Cài đặt gói SNMP (nếu chưa có)
log "Kiểm tra và cài đặt gói SNMP..."
if ! command -v snmpwalk &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y snmp snmp-mibs-downloader
fi
check_error "Cài đặt gói SNMP"

# 5. Cài đặt và chạy SNMP Daemon (nếu cần)
log "Kiểm tra và cài đặt SNMP Daemon..."
if ! systemctl is-active snmpd &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y snmpd
    sudo systemctl enable snmpd
    sudo systemctl start snmpd
fi
check_error "SNMP Daemon đang chạy"

# 6. Cấu hình SNMP Daemon
log "Cấu hình SNMP Daemon..."
SNMP_CONF="/etc/snmp/snmpd.conf"
if ! grep -q "rocommunity hissc 172.18.10.0/24" "$SNMP_CONF"; then
    echo "rocommunity hissc 172.18.10.0/24" | sudo tee -a "$SNMP_CONF"
    sudo systemctl restart snmpd
fi
check_error "Cấu hình SNMP Daemon"

# 7. Xác minh cấu hình Telegraf
log "Kiểm tra cấu hình Telegraf..."
grep -vE '^\s*#|^\s*$' /etc/telegraf/telegraf.conf
check_error "Cấu hình Telegraf hợp lệ"

# 8. Kiểm tra kết nối mạng
log "Kiểm tra port mạng..."
netstat -tulnp | grep -E "161|8086"
check_error "Port SNMP (161) và InfluxDB (8086) đang lắng nghe"

log "${GREEN}Kiểm tra Telegraf hoàn tất!${NC}"
