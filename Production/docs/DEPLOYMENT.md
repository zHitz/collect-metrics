# 📚 Hướng Dẫn Triển Khai Chi Tiết

## 📋 Mục Lục
1. [Yêu Cầu Hệ Thống](#yêu-cầu-hệ-thống)
2. [Chuẩn Bị](#chuẩn-bị)
3. [Triển Khai Cơ Bản](#triển-khai-cơ-bản)
4. [Triển Khai Nâng Cao](#triển-khai-nâng-cao)
5. [Cấu Hình Modules](#cấu-hình-modules)
6. [Kiểm Tra Hệ Thống](#kiểm-tra-hệ-thống)

## 🖥️ Yêu Cầu Hệ Thống

### Phần Cứng Tối Thiểu
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disk**: 20GB SSD
- **Network**: 100Mbps

### Phần Cứng Khuyến Nghị
- **CPU**: 4 cores
- **RAM**: 8GB
- **Disk**: 50GB SSD
- **Network**: 1Gbps

### Hệ Điều Hành
- Ubuntu 20.04/22.04 LTS
- CentOS 7/8/Stream
- Rocky Linux 8/9
- AlmaLinux 8/9
- Debian 10/11

## 🛠️ Chuẩn Bị

### 1. Clone Repository
```bash
git clone <repository-url>
cd new_project
```

### 2. Cấu Hình Môi Trường
```bash
# Sao chép file cấu hình mẫu
cp .env.example .env

# Chỉnh sửa file cấu hình
nano .env
```

### 3. Cấu Hình Cơ Bản
Các thông số quan trọng cần điều chỉnh:

```env
# Bật/tắt modules
ENABLE_SNMP=false              # true nếu cần giám sát network devices
ENABLE_EXEC_SCRIPTS=false      # true nếu cần custom monitoring

# Thông tin truy cập
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<tự động generate>

# Network settings
INFLUXDB_PORT=8086
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090
```

## 🚀 Triển Khai Cơ Bản

### Triển Khai Tự Động
```bash
# Chạy script deployment
./scripts/deploy.sh
```

Script sẽ tự động:
- ✅ Kiểm tra và cài đặt Docker
- ✅ Tạo cấu hình cần thiết
- ✅ Khởi động các services
- ✅ Import dashboards mẫu

### Triển Khai Thủ Công
```bash
# 1. Cài đặt Docker (nếu chưa có)
./scripts/install-docker.sh

# 2. Tạo cấu hình
./scripts/configure.sh

# 3. Khởi động services
docker compose up -d
```

## 🔧 Triển Khai Nâng Cao

### Triển Khai Với SNMP
```bash
# 1. Bật SNMP trong .env
ENABLE_SNMP=true

# 2. Cấu hình thiết bị SNMP
TELEGRAF_SNMP_AGENTS=switch1:192.168.1.10:161:public,router1:192.168.1.1:161:public

# 3. Deploy với profile SNMP
docker compose --profile snmp up -d
```

### Triển Khai Với Custom Scripts
```bash
# 1. Bật Exec Scripts trong .env
ENABLE_EXEC_SCRIPTS=true

# 2. Đặt scripts vào thư mục
cp your-script.sh exec-scripts/

# 3. Deploy với profile exec
docker compose --profile exec up -d
```

### Triển Khai Full Stack
```bash
# Bật tất cả modules
ENABLE_SNMP=true
ENABLE_EXEC_SCRIPTS=true
ENABLE_ALERTMANAGER=true

# Deploy
docker compose --profile snmp --profile exec --profile alerting up -d
```

## 📦 Cấu Hình Modules

### Module Prometheus (Server Monitoring)
1. **Thêm Node Exporter trên server cần monitor**:
   ```bash
   # Trên server target
   docker run -d \
     --name node-exporter \
     --restart unless-stopped \
     -p 9100:9100 \
     -v /proc:/host/proc:ro \
     -v /sys:/host/sys:ro \
     -v /:/rootfs:ro \
     prom/node-exporter:latest \
     --path.procfs=/host/proc \
     --path.sysfs=/host/sys \
     --path.rootfs=/rootfs
   ```

2. **Thêm target vào Prometheus**:
   ```bash
   # Chỉnh sửa .env
   NODE_EXPORTER_TARGETS=server1:9100,server2:9100,server3:9100
   
   # Reload configuration
   ./scripts/configure.sh
   docker compose restart prometheus
   ```

### Module SNMP (Network Monitoring)
1. **Cấu hình thiết bị mạng**:
   - Enable SNMP v2c hoặc v3
   - Set community string
   - Allow access từ monitoring server

2. **Thêm thiết bị vào monitoring**:
   ```env
   # Format: name:host:port:community
   TELEGRAF_SNMP_AGENTS=cisco-sw1:10.0.0.1:161:public,hp-sw1:10.0.0.2:161:public
   ```

3. **SNMP v3 configuration**:
   ```env
   TELEGRAF_SNMP_VERSION=3
   TELEGRAF_SNMP_SEC_NAME=snmpuser
   TELEGRAF_SNMP_AUTH_PROTOCOL=SHA
   TELEGRAF_SNMP_AUTH_PASSWORD=authpass123
   TELEGRAF_SNMP_PRIV_PROTOCOL=AES
   TELEGRAF_SNMP_PRIV_PASSWORD=privpass123
   ```

### Module Exec Scripts (Custom Monitoring)
1. **Tạo custom script**:
   ```bash
   # exec-scripts/custom_metrics.sh
   #!/bin/bash
   # Output format: measurement,tag1=value1 field1=value1,field2=value2 timestamp
   
   echo "custom_app,app=myapp,env=prod requests=100,latency=25.5,errors=2"
   ```

2. **Cấu hình trong telegraf-exec.conf**:
   ```toml
   [[inputs.exec]]
     commands = ["/scripts/custom_metrics.sh"]
     timeout = "30s"
     data_format = "influx"
     interval = "60s"
   ```

## ✅ Kiểm Tra Hệ Thống

### 1. Kiểm Tra Services
```bash
# Xem status các containers
docker compose ps

# Xem logs
docker compose logs -f influxdb
docker compose logs -f grafana
docker compose logs -f prometheus
```

### 2. Kiểm Tra Endpoints
- **Grafana**: http://localhost:3000
- **InfluxDB**: http://localhost:8086
- **Prometheus**: http://localhost:9090

### 3. Kiểm Tra Metrics
```bash
# Prometheus metrics
curl http://localhost:9090/metrics

# Node exporter metrics
curl http://localhost:9100/metrics

# InfluxDB health
curl http://localhost:8086/health
```

### 4. Troubleshooting Commands
```bash
# Restart specific service
docker compose restart grafana

# Stop all services
docker compose down

# Start với logs
docker compose up

# Clean restart
docker compose down -v
docker compose up -d
```

## 🔒 Bảo Mật

### 1. Thay Đổi Mật Khẩu Mặc Định
```bash
# Script tự động generate passwords nếu dùng .env.example
# Kiểm tra passwords trong .env
grep PASSWORD .env
```

### 2. Cấu Hình Firewall
```bash
# UFW (Ubuntu)
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 8086/tcp  # InfluxDB

# Firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=9090/tcp
sudo firewall-cmd --permanent --add-port=8086/tcp
sudo firewall-cmd --reload
```

### 3. Enable HTTPS
Xem [CONFIGURATION.md](CONFIGURATION.md) để cấu hình HTTPS cho Grafana.

## 🔄 Cập Nhật Hệ Thống

### Update Images
```bash
# Pull latest images
docker compose pull

# Restart với images mới
docker compose up -d
```

### Backup Trước Khi Update
```bash
# Backup data
./scripts/backup.sh

# Update
docker compose pull
docker compose up -d
```

## 📞 Hỗ Trợ

Nếu gặp vấn đề, vui lòng:
1. Kiểm tra logs: `docker compose logs [service-name]`
2. Xem [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. Tạo issue trên GitHub