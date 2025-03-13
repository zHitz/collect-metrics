#!/bin/bash

# Script kiểm tra InfluxDB
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

log "Bắt đầu kiểm tra InfluxDB..."

# Tải biến từ .env
source "$(dirname "$0")/../.env"

# 1. Kiểm tra databases trong InfluxDB
log "Kiểm tra databases trong InfluxDB..."
docker exec influxdb influx -username "$INFLUXDB_USERNAME" -password "$INFLUXDB_PASSWORD" -execute "SHOW DATABASES"
check_error "Danh sách databases"

# 2. Chọn database telegraf
log "Chọn database telegraf..."
docker exec influxdb influx -username "$INFLUXDB_USERNAME" -password "$INFLUXDB_PASSWORD" -database "$INFLUXDB_BUCKET" -execute "SHOW MEASUREMENTS"
check_error "Chuyển sang database $INFLUXDB_BUCKET"

# 3. Kiểm tra measurements
log "Kiểm tra measurements có sẵn..."
docker exec influxdb influx -username "$INFLUXDB_USERNAME" -password "$INFLUXDB_PASSWORD" -database "$INFLUXDB_BUCKET" -execute "SHOW MEASUREMENTS"
check_error "Danh sách measurements"

# 4. Truy vấn dữ liệu
log "Truy vấn tất cả measurements..."
docker exec influxdb influx -username "$INFLUXDB_USERNAME" -password "$INFLUXDB_PASSWORD" -database "$INFLUXDB_BUCKET" -execute "SELECT * FROM /.*/ LIMIT 5"
check_error "Dữ liệu SNMP trong measurements"

# 5. Chèn dữ liệu thử nghiệm
log "Chèn dữ liệu thử nghiệm..."
docker exec influxdb influx -username "$INFLUXDB_USERNAME" -password "$INFLUXDB_PASSWORD" -database "$INFLUXDB_BUCKET" -execute "INSERT test_measurement,location=server1 value=10"
check_error "Chèn dữ liệu thử nghiệm"

# 6. Kiểm tra log InfluxDB
log "Kiểm tra log InfluxDB..."
docker logs influxdb | tail -20
check_error "Log InfluxDB không có lỗi"

log "${GREEN}Kiểm tra InfluxDB hoàn tất!${NC}"
