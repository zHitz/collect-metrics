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
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    log "${RED}Không tìm thấy $ENV_FILE. Vui lòng tạo file theo mẫu.${NC}"
    exit 1
fi
source "$ENV_FILE"
log "Đã tải cấu hình từ $ENV_FILE"

# --- Tạo mật khẩu ngẫu nhiên cho Portainer nếu chưa được đặt ---
if [ -z "$PORTAINER_PASSWORD" ]; then
    PORTAINER_PASSWORD=$(openssl rand -base64 12)
    echo "PORTAINER_PASSWORD=$PORTAINER_PASSWORD" >> "$ENV_FILE"
    log "Đã tạo mật khẩu Portainer mới"
fi

# --- Tạo thư mục dữ liệu cho Portainer ---
PORTAINER_DATA_DIR=${PORTAINER_DATA_DIR:-./portainer_data}
mkdir -p "$PORTAINER_DATA_DIR"
check_error "Không thể tạo thư mục dữ liệu Portainer"

# --- Khởi tạo Docker Swarm nếu chưa có ---
if ! docker info | grep -q "Swarm: active"; then
    log "Khởi tạo Docker Swarm..."
    docker swarm init --advertise-addr $(hostname -i) 2>/dev/null || true
fi

# --- Gọi các script phụ ---
BASE_DIR="$(dirname "$0")"
"$BASE_DIR/install_docker.sh"
"$BASE_DIR/setup_network.sh"
"$BASE_DIR/config_telegraf.sh"

# --- Triển khai Portainer ---
log "Triển khai Portainer..."
docker-compose -f docker-compose.portainer.yml up -d
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

# Lấy JWT token để thao tác với API
JWT_TOKEN=$(curl -s -X POST "http://localhost:9000/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"$PORTAINER_PASSWORD\"}" | jq -r .jwt)

if [ -z "$JWT_TOKEN" ]; then
    log "${RED}Không thể lấy token xác thực từ Portainer${NC}"
    exit 1
fi

# --- Tạo và triển khai Stack ---
log "Tạo Stack Monitoring..."

# Đọc nội dung file docker-compose.yml và mã hóa base64
STACK_CONTENT=$(base64 -w 0 ./stacks/monitoring/docker-compose.yml)
ENV_CONTENT=$(base64 -w 0 ./stacks/monitoring/.env)

# Tạo Stack qua Portainer API
curl -s -X POST "http://localhost:9000/api/stacks" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"monitoring\",
        \"stackFileContent\": \"$STACK_CONTENT\",
        \"env\": $(jq -n --arg env "$ENV_CONTENT" '[$env]'),
        \"swarmID\": \"$(docker info --format '{{.Swarm.Cluster.ID}}')\",
        \"type\": 1
    }"

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
log "URL: http://localhost:9000"
log "Username: admin"
log "Password: $PORTAINER_PASSWORD"
log "\nStack Monitoring đã được triển khai tự động trong Portainer"
log "Chỉnh sửa .env để thay đổi cấu hình"
