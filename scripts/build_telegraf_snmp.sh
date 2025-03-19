#!/bin/bash

# Script để build image Telegraf với MIBs SNMP

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

# --- Lấy Dockerfile---
DOCKERFILE="$PROJECT_DIR/Dockerfile"

# Kiểm tra file Dockerfile có tồn tại không
if [ ! -f "$DOCKERFILE" ]; then
    echo "Không tìm thấy $DOCKERFILE. Vui lòng tạo file Dockerfile."
    exit 1
fi

# Mặc định version nếu không được cung cấp
DEFAULT_TELEGRAF_VERSION="1.28.0"

# Lấy version từ tham số dòng lệnh hoặc sử dụng mặc định
TELEGRAF_VERSION=${TELEGRAF_VERSION:-$DEFAULT_TELEGRAF_VERSION}

# Tên image
IMAGE_NAME="telegraf-snmp"
TAG="$TELEGRAF_VERSION"

echo "=== Bắt đầu build image $IMAGE_NAME:$TAG ==="
echo "Sử dụng Telegraf version: $TELEGRAF_VERSION"

# Thực hiện build
docker build \
  --build-arg TELEGRAF_VERSION=$TELEGRAF_VERSION \
  -t $IMAGE_NAME:$TAG \
  -f $DOCKERFILE .

# Kiểm tra kết quả
if [ $? -eq 0 ]; then
  echo "=== Build thành công: $IMAGE_NAME:$TAG ==="
  echo "Bạn có thể chạy image với câu lệnh:"
  echo "docker run --rm $IMAGE_NAME:$TAG"
else
  echo "=== Build thất bại! ==="
  exit 1
fi

# Hiển thị thông tin image
echo "=== Thông tin image ==="
docker image ls $IMAGE_NAME:$TAG 