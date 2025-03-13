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

# 1. Kiểm tra buckets trong InfluxDB
log "Kiểm tra buckets trong InfluxDB..."
docker exec influxdb influx bucket list --host "http://localhost:8086" --token "$INFLUXDB_TOKEN" --org "$INFLUXDB_ORG"
check_error "Danh sách buckets"

# 2. Kiểm tra measurements
log "Kiểm tra measurements trong bucket $INFLUXDB_BUCKET..."
docker exec influxdb influx query "from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> keep(columns: [\"_measurement\"]) |> distinct()" \
  --host "http://localhost:8086" \
  --token "$INFLUXDB_TOKEN" \
  --org "$INFLUXDB_ORG"
check_error "Danh sách measurements"

# 3. Truy vấn dữ liệu
log "Truy vấn dữ liệu mẫu từ bucket $INFLUXDB_BUCKET..."
# docker exec influxdb influx query "from(bucket: \"$INFLUXDB_BUCKET\") |> range(start: -1h) |> limit(n: 1)" \
#   --host "http://localhost:8086" \
#   --token "$INFLUXDB_TOKEN" \
#   --org "$INFLUXDB_ORG"
# check_error "Dữ liệu mẫu"

# 4. Kiểm tra log InfluxDB
log "Kiểm tra log InfluxDB..."
docker logs influxdb | tail -10
check_error "Log InfluxDB không có lỗi"

log "${GREEN}Kiểm tra InfluxDB hoàn tất!${NC}"
