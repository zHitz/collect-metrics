# 🚀 Hệ Thống Giám Sát Tài Nguyên Tích Hợp

[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-Required-blue.svg)](https://docs.docker.com/compose/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Tổng Quan

Hệ thống giám sát tài nguyên toàn diện, được thiết kế để triển khai nhanh chóng và linh hoạt cho mọi khách hàng. Hệ thống sử dụng các công nghệ hàng đầu để thu thập, lưu trữ và hiển thị metrics từ servers và network devices.

### ✨ Tính Năng Chính

- **🔍 Server Monitoring**: Giám sát toàn diện servers Linux/Windows với Prometheus + Node Exporter
- **🌐 Network Monitoring**: Giám sát network devices (routers, switches) qua SNMP
- **📊 Custom Metrics**: Thu thập metrics tùy chỉnh qua exec scripts
- **📈 Visualization**: Dashboard đẹp mắt với Grafana
- **🚨 Alerting**: Hệ thống cảnh báo thông minh
- **🔧 Auto Deployment**: Scripts tự động hóa triển khai và cấu hình

## 🏗️ Kiến Trúc Hệ Thống

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Prometheus +   │────▶│    InfluxDB      │◀────│    Grafana      │
│  Node Exporter  │     │  (Time Series    │     │ (Visualization) │
│  (Servers)      │     │   Database)      │     └─────────────────┘
└─────────────────┘     └──────────────────┘
                               ▲      ▲
┌─────────────────┐           │      │
│  Telegraf SNMP  │───────────┘      │
│  (Network       │                  │
│   Devices)      │                  │
└─────────────────┘                  │
                                     │
┌─────────────────┐                  │
│ Telegraf Exec   │──────────────────┘
│ (Custom Scripts)│
└─────────────────┘
```

## 📦 Cấu Trúc Project

```
collect-metrics/
├── 📁 configs/                    # Cấu hình services
│   ├── 📁 grafana/               # Grafana provisioning
│   ├── 📁 prometheus/            # Prometheus configs
│   └── 📁 telegraf/              # Telegraf configs
├── 📁 dashboards/                # Grafana dashboards
│   ├── 📁 system/               # Server monitoring
│   ├── 📁 network/              # Network monitoring
│   └── 📁 custom/               # Custom dashboards
├── 📁 scripts/                   # Deployment scripts
│   ├── deploy.sh                # Main deployment script
│   ├── configure.sh             # Configuration script
│   ├── backup.sh                # Backup script
│   └── 📁 troubleshoot/         # Troubleshooting tools
├── 📁 exec-scripts/             # Custom monitoring scripts
├── 📁 docs/                     # Documentation
├── 📁 data/                     # Persistent data (auto-created)
├── docker-compose.yml           # Docker Compose configuration
├── Dockerfile                   # Custom Telegraf image
├── .env.example                 # Environment template
├── checklist.md                 # Production deployment checklist
└── README.md                    # This file
```

## 🚀 Triển Khai Nhanh

### Yêu Cầu Hệ Thống

- **OS**: Linux (Ubuntu 20.04+ / CentOS 8+)
- **RAM**: Tối thiểu 4GB, khuyến nghị 8GB+
- **CPU**: Tối thiểu 2 cores, khuyến nghị 4 cores+
- **Disk**: Tối thiểu 50GB, khuyến nghị 100GB+
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+

### Bước 1: Clone và Chuẩn Bị

```bash
# Clone repository
git clone <repository-url>
cd collect-metrics

# Copy environment template
cp .env.example .env
```

### Bước 2: Cấu Hình

Chỉnh sửa file `.env` theo nhu cầu:

```bash
# Core Configuration
COMPOSE_PROJECT_NAME=monitoring
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your_secure_password

# Optional Modules
ENABLE_SNMP=false              # Bật/tắt SNMP monitoring
ENABLE_EXEC_SCRIPTS=false      # Bật/tắt custom scripts
ENABLE_ALERTING=false          # Bật/tắt alerting
ENABLE_PORTAINER=false         # Bật/tắt Portainer

# SNMP Configuration (nếu ENABLE_SNMP=true)
INFLUXDB_USERNAME=admin
INFLUXDB_PASSWORD=your_influxdb_password
INFLUXDB_ORG=your_org
INFLUXDB_BUCKET=metrics
INFLUXDB_TOKEN=your_token

# Service Images (Flexible - có thể thay đổi toàn bộ image, không chỉ version)
GRAFANA_IMAGE=grafana/grafana:12.2.0-16636675413
PROMETHEUS_IMAGE=prom/prometheus:v3.5.0
NODE_EXPORTER_IMAGE=prom/node-exporter:v1.9.0
INFLUXDB_IMAGE=influxdb:2.7.0
TELEGRAF_IMAGE=telegraf:1.27.0
ALERTMANAGER_IMAGE=prom/alertmanager:v0.25.0
PORTAINER_IMAGE=portainer/portainer-ce:lts
```

### Bước 3: Triển Khai

```bash
# Triển khai hệ thống
./scripts/deploy.sh
```

### Bước 4: Kiểm Tra

Sau khi triển khai thành công, truy cập:

- **Grafana**: http://localhost:3000 (admin/your_password)
- **Prometheus**: http://localhost:9090
- **Node Exporter**: http://localhost:9100

## 🔧 Quản Lý Hệ Thống

### Restart/Redeploy

```bash
# Restart với cập nhật images
./scripts/restart.sh

# Restart không cập nhật images
UPDATE_IMAGES=false ./scripts/restart.sh

# Restart với cleanup hoàn toàn (cẩn thận!)
CLEAN_VOLUMES=true CLEAN_IMAGES=true ./scripts/restart.sh
```

### Backup và Restore

```bash
# Tạo backup
./scripts/backup.sh

# Restore từ backup (nếu cần)
# Xem docs/BACKUP.md để biết chi tiết
```

### Kiểm Tra Trạng Thái

```bash
# Kiểm tra services
docker-compose ps

# Xem logs
docker-compose logs [service-name]

# Kiểm tra profiles được bật
./scripts/test-profiles.sh
```

## 📊 Modules

### 1. Server Monitoring (Mặc định)

Giám sát servers Linux/Windows với Prometheus + Node Exporter:

- **Metrics**: CPU, Memory, Disk, Network, Load, System info
- **Ports**: 9090 (Prometheus), 9100 (Node Exporter)
- **Dashboard**: System Overview, Server Metrics

### 2. Network Device Monitoring (Tùy chọn)

Giám sát network devices qua SNMP:

- **Kích hoạt**: `ENABLE_SNMP=true` trong `.env`
- **Hỗ trợ**: Cisco, Juniper, HP, Dell switches/routers
- **Metrics**: Interface stats, CPU, Memory, Temperature
- **Ports**: 8086 (InfluxDB)
- **Dashboard**: Network Devices Overview

### 3. Custom Monitoring (Tùy chọn)

Thu thập metrics tùy chỉnh qua exec scripts:

- **Kích hoạt**: `ENABLE_EXEC_SCRIPTS=true` trong `.env`
- **Scripts**: Python, Bash, hoặc bất kỳ executable nào
- **Use cases**: API monitoring, database metrics, custom business logic

### 4. Alerting (Tùy chọn)

Hệ thống cảnh báo thông minh:

- **Kích hoạt**: `ENABLE_ALERTING=true` trong `.env`
- **Components**: AlertManager, Prometheus rules
- **Channels**: Email, Slack, Webhook
- **Ports**: 9093 (AlertManager)

## 🔐 Bảo Mật

### Mật Khẩu và Credentials

- Tất cả mật khẩu được generate tự động và lưu trong `.env`
- Sử dụng mật khẩu mạnh cho production
- Không commit file `.env` vào git

### Network Security

- Services chỉ expose ports cần thiết
- Docker networks được isolate
- Firewall rules được cấu hình tự động

### Access Control

- Grafana admin access được bảo vệ
- Prometheus API có thể được bảo vệ với reverse proxy
- InfluxDB token-based authentication

## 🛠️ Troubleshooting

### Lỗi Thường Gặp

#### 1. Permission Errors

```bash
# Fix permissions
./scripts/fix-permissions.sh

# Hoặc fix thủ công
sudo chown -R 472:472 ./data/grafana
sudo chown -R 65534:65534 ./data/prometheus
```

#### 2. Port Conflicts

```bash
# Kiểm tra ports đang sử dụng
netstat -tulpn | grep -E ':(3000|9090|9100|8086)'

# Thay đổi ports trong .env nếu cần
GRAFANA_PORT=3001
PROMETHEUS_PORT=9091
```

#### 3. Docker Issues

```bash
# Restart Docker service
sudo systemctl restart docker

# Clean Docker system
docker system prune -a
```

### Logs và Debugging

```bash
# Xem logs của tất cả services
docker-compose logs

# Xem logs của service cụ thể
docker-compose logs grafana
docker-compose logs prometheus

# Follow logs real-time
docker-compose logs -f [service-name]
```

### Health Checks

```bash
# Kiểm tra health của services
docker-compose ps

# Test endpoints
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9090/-/healthy   # Prometheus
```

## 📈 Mở Rộng Hệ Thống

### Thêm Servers Mới

1. **Cài đặt Node Exporter** trên server mới:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install prometheus-node-exporter
   
   # CentOS/RHEL
   sudo yum install prometheus2-node_exporter
   ```

2. **Thêm target** vào Prometheus config:
   ```yaml
   # configs/prometheus/targets/servers.yml
   - targets: ['new-server:9100']
     labels:
       instance: 'new-server'
       env: 'production'
   ```

3. **Reload Prometheus**:
   ```bash
   curl -X POST http://localhost:9090/-/reload
   ```

### Thêm Network Devices

1. **Enable SNMP** trên device
2. **Thêm vào cấu hình**:
   ```bash
   # Trong .env
   TELEGRAF_SNMP_HOSTS=192.168.1.1,192.168.1.2
   ```
3. **Restart Telegraf**:
   ```bash
   docker-compose restart telegraf
   ```

### Thêm Custom Metrics

1. **Tạo script** trong `exec-scripts/`:
   ```python
   # exec-scripts/custom_metric.py
   import json
   import time
   
   result = {
       "measurement": "custom_metric",
       "tags": {"host": "server1"},
       "fields": {"value": 42}
   }
   print(json.dumps(result))
   ```

2. **Thêm vào Telegraf config**:
   ```toml
   # configs/telegraf/telegraf.conf
   [[inputs.exec]]
     commands = ["python3 /scripts/custom_metric.py"]
     timeout = "5s"
   ```

3. **Restart Telegraf**:
   ```bash
   docker-compose restart telegraf
   ```

## 📚 Tài Liệu Chi Tiết

- **[Hướng dẫn triển khai](docs/DEPLOYMENT.md)** - Chi tiết về deployment
- **[Cấu hình nâng cao](docs/CONFIGURATION.md)** - Cấu hình chi tiết
- **[Xử lý sự cố](docs/TROUBLESHOOTING.md)** - Troubleshooting guide
- **[Production Checklist](checklist.md)** - Checklist cho production

## 🤝 Đóng Góp

1. Fork project
2. Tạo feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Tạo Pull Request

## 📄 License

Project này được phân phối dưới MIT License. Xem file `LICENSE` để biết thêm chi tiết.

## 🆘 Hỗ Trợ

- **Email**: support@example.com
- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Documentation**: [Wiki](https://github.com/your-repo/wiki)

---

**Version**: 2.0.0  
**Last Updated**: 2024  
**Maintainer**: DevOps Team