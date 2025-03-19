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

# --- Tải file .env ---
# Xác định đường dẫn tuyệt đối của thư mục chứa script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Xác định đường dẫn của thư mục dự án (thư mục cha của SCRIPT_DIR)
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Đường dẫn đầy đủ của file .env
ENV_FILE="$PROJECT_DIR/.env"

# Kiểm tra file .env có tồn tại không
if [ ! -f "$ENV_FILE" ]; then
    echo "Không tìm thấy $ENV_FILE. Vui lòng tạo file theo mẫu."
    exit 1
fi

# Tải biến môi trường từ file .env
source "$ENV_FILE"
log "Đã tải cấu hình từ $ENV_FILE"

# --- Tạo mật khẩu ngẫu nhiên cho Portainer nếu chưa được đặt ---
if [ -z "$PORTAINER_PASSWORD" ]; then
    PORTAINER_PASSWORD=$(openssl rand -base64 12)
    echo "PORTAINER_PASSWORD=$PORTAINER_PASSWORD" >> "$ENV_FILE"
    log "Đã tạo mật khẩu Portainer mới"
fi

# --- Tạo thư mục dữ liệu cho Portainer ---
PORTAINER_DATA_DIR=${PORTAINER_DATA_DIR:-/opt/portainer/data}
mkdir -p "$PORTAINER_DATA_DIR"
check_error "Không thể tạo thư mục dữ liệu Portainer"


# --- Gọi các script phụ ---
BASE_DIR="$(dirname "$0")"
"$BASE_DIR/install_docker.sh"
"$BASE_DIR/setup_network.sh"
"$BASE_DIR/config_telegraf.sh"
"$BASE_DIR/build_telegraf_snmp.sh"

# --- Triển khai Portainer ---
# Đường dẫn thư mục chứa file docker-compose
COMPOSE_DIR="$PROJECT_DIR/stacks/portainer"
echo "Đường dẫn thư mục chứa file docker-compose: $COMPOSE_DIR"
# Di chuyển vào thư mục chứa docker-compose.yml
cd "$COMPOSE_DIR" || { echo "Không thể chuyển vào thư mục $COMPOSE_DIR"; exit 1; }
log "Triển khai Portainer..."
docker-compose down
docker-compose -f docker-compose.yml up -d
check_error "Không thể triển khai Portainer"

# --- Chờ Portainer khởi động ---
log "Chờ Portainer khởi động..."
sleep 10

# --- Tự động cấu hình Portainer ---
log "Cấu hình Portainer..."
# Khởi tạo admin user
PORTAINER_INIT_RESPONSE=$(curl -s -X POST "http://localhost:9000/api/users/admin/init" \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"$PORTAINER_PASSWORD\"}")

check_error "Không thể tạo Stack trong Portainer"

# --- Chờ các container khởi động ---
log "Chờ các container khởi động..."
sleep 20

# --- Xác minh triển khai ---
log "Kiểm tra trạng thái các services..."
docker service ls

# --- Thông tin kết thúc ---
log "${GREEN}Triển khai hoàn tất!${NC}"
log "Truy cập InfluxDB tại: http://localhost:8086"
log "Username: $INFLUXDB_USERNAME"
log "Password: $INFLUXDB_PASSWORD"
log "Token: $INFLUXDB_TOKEN"
log "Dữ liệu trong bucket '$INFLUXDB_BUCKET'"

log "\nThông tin Portainer:"
log "Truy cập Portainer tại: http://localhost:9443"
log "Username: admin"
log "Password: $PORTAINER_PASSWORD"
log "\nStack Monitoring đã được triển khai tự động trong Portainer"
log "Chỉnh sửa .env để thay đổi cấu hình"
