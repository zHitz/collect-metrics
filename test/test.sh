#!/bin/bash

# Hàm tạo mật khẩu ngẫu nhiên
generate_password() {
    local length=${1:-16}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    echo
}

# Hàm hash mật khẩu bằng bcrypt
hash_bcrypt() {
    local password="$1"

    if command -v htpasswd &> /dev/null; then
        htpasswd -nbB admin "$password" | cut -d ':' -f2
    elif command -v python3 &> /dev/null; then
        python3 -c "import bcrypt; print(bcrypt.hashpw(b'$password', bcrypt.gensalt()).decode())"
    else
        echo "Error: Không có htpasswd hoặc python3 để tạo bcrypt hash." >&2
        return 1
    fi
}

# Ví dụ sử dụng
PASSWORD=$(generate_password 16)
HASHED=$(hash_bcrypt "$PASSWORD")

echo "🔐 Mật khẩu ngẫu nhiên: $PASSWORD"
echo "🔒 Bcrypt hash để dùng trong docker-compose: $HASHED"
