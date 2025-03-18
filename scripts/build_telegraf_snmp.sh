#!/bin/bash

# Script để build image Telegraf với MIBs SNMP

# --- Tải file .env ---
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    log "${RED}Không tìm thấy $ENV_FILE. Vui lòng tạo file theo mẫu.${NC}"
    exit 1
fi
source "$ENV_FILE"


# Mặc định version nếu không được cung cấp
DEFAULT_TELEGRAF_VERSION="1.28.0"

# Lấy version từ tham số dòng lệnh hoặc sử dụng mặc định
TELEGRAF_VERSION=${$TELEGRAF_VERSION:-$DEFAULT_TELEGRAF_VERSION}

# Tên image
IMAGE_NAME="telegraf-snmp"
TAG="$TELEGRAF_VERSION"

echo "=== Bắt đầu build image $IMAGE_NAME:$TAG ==="
echo "Sử dụng Telegraf version: $TELEGRAF_VERSION"

# Thực hiện build
docker build \
  --build-arg TELEGRAF_VERSION=$TELEGRAF_VERSION \
  -t $IMAGE_NAME:$TAG \
  -f Dockerfile .

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