#!/bin/bash

# Script chính để triển khai InfluxDB và Telegraf bằng Docker Compose
# Ngày: 07/03/2025

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
        exit 1
    fi
}

# --- Đảm bảo luôn có file .env trước khi chạy tiếp ---
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ] || [ ! -s "$ENV_FILE" ]; then
    log "${RED}Không tìm thấy hoặc file $ENV_FILE rỗng. Vui lòng tạo file .env từ .env.example và điền thông tin cấu hình.${NC}"
    exit 1
fi
source "$ENV_FILE"
log "Đã tải cấu hình từ $ENV_FILE"

# --- Gọi các script phụ ---
BASE_DIR="$(dirname "$0")"
"$BASE_DIR/install_docker.sh"
"$BASE_DIR/setup_network.sh"
"$BASE_DIR/config_telegraf.sh"

# --- Triển khai bằng Docker Compose ---
log "Triển khai InfluxDB và Telegraf bằng Docker Compose..."
cd "$(dirname "$0")/.."  # Chuyển đến thư mục chứa docker-compose.yml
docker compose down 2>/dev/null  # Dừng và xóa container cũ nếu có
docker compose up -d
check_error "Không thể triển khai Docker Compose"

# --- Xác minh ---
log "Kiểm tra trạng thái container..."
sleep 5
docker ps -a

log "Kiểm tra log Telegraf..."
docker logs telegraf 2>/dev/null || log "Chưa có log từ Telegraf (có thể container chưa khởi động)."

# --- Thông tin kết thúc ---
log "${GREEN}Triển khai hoàn tất!${NC}"
log "Truy cập InfluxDB tại: http://localhost:8086"
log "Username: $INFLUXDB_USERNAME"
log "Password: $INFLUXDB_PASSWORD"
log "Token: $INFLUXDB_TOKEN"
log "Dữ liệu trong bucket '$INFLUXDB_BUCKET'."
log "Chỉnh sửa .env để thay đổi cấu hình."
