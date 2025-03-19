#!/bin/bash

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

# In thử biến môi trường để kiểm tra
echo "Đã load biến môi trường từ $ENV_FILE"