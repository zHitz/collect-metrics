# 🚀 Hệ Thống Giám Sát Tài Nguyên Tích Hợp

## 📋 Tổng Quan

Hệ thống giám sát tài nguyên toàn diện, được thiết kế để triển khai nhanh chóng và linh hoạt cho mọi khách hàng. Hệ thống sử dụng các công nghệ hàng đầu để thu thập, lưu trữ và hiển thị metrics từ servers và network devices.

## 🏗️ Kiến Trúc

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

## ✨ Tính Năng

### 🔹 Core Features
- **InfluxDB 2.x**: Time-series database hiệu suất cao
- **Grafana**: Dashboard visualization mạnh mẽ
- **Prometheus**: Giám sát servers với node_exporter
- **Deployment tự động**: Scripts cài đặt và cấu hình

### 🔹 Modules Tùy Chọn
- **SNMP Monitoring**: Giám sát network devices (routers, switches)
- **Custom Scripts**: Thu thập metrics tùy chỉnh qua exec scripts

## 📦 Cấu Trúc Project

```
new_project/
├── docker-compose.yml      # Docker Compose với profiles
├── .env.example           # Template cấu hình
├── configs/               # Cấu hình cho các services
│   ├── prometheus/       # Prometheus configs
│   ├── grafana/         # Grafana provisioning
│   └── telegraf/        # Telegraf configs (base, snmp, exec)
├── scripts/              # Scripts deployment
├── dashboards/          # Grafana dashboards
├── exec-scripts/        # Custom monitoring scripts
└── docs/               # Tài liệu chi tiết
```

## 🚀 Triển Khai Nhanh

### 1. Clone và chuẩn bị
```bash
git clone <repository>
cd new_project
cp .env.example .env
```

### 2. Cấu hình
Chỉnh sửa file `.env` theo nhu cầu:
- Bật/tắt các modules
- Cấu hình thông tin kết nối
- Thiết lập credentials

### 3. Deploy
```bash
./scripts/deploy.sh
```

## 🔧 Modules

### 1. Server Monitoring (Mặc định)
- Sử dụng Prometheus + Node Exporter
- Thu thập: CPU, Memory, Disk, Network, Load
- Dashboard sẵn có cho Linux servers

### 2. Network Device Monitoring (Tùy chọn)
- Kích hoạt: `ENABLE_SNMP=true`
- Hỗ trợ: Cisco, Juniper, HP, Dell switches/routers
- Thu thập: Interface stats, CPU, Memory

### 3. Custom Monitoring (Tùy chọn)
- Kích hoạt: `ENABLE_EXEC_SCRIPTS=true`
- Viết scripts Python/Bash tùy chỉnh
- Thu thập metrics từ API, databases, v.v.

## 📊 Dashboards

### Có sẵn
- **Server Overview**: Tổng quan servers Linux/Windows
- **Network Devices**: Giám sát switches/routers
- **Alert Dashboard**: Tổng hợp cảnh báo

### Tùy chỉnh
- Import dashboards từ Grafana Labs
- Tạo dashboards theo yêu cầu riêng

## 🔐 Bảo Mật

- Mật khẩu mạnh tự động generate
- HTTPS cho Grafana (optional)
- Network isolation với Docker networks
- Secrets management qua environment variables

## 📈 Mở Rộng

### Thêm servers mới
1. Cài đặt node_exporter trên server mới
2. Thêm target vào Prometheus config
3. Reload Prometheus

### Thêm network devices
1. Enable SNMP trên device
2. Thêm vào TELEGRAF_SNMP_HOSTS
3. Restart Telegraf SNMP

### Thêm custom metrics
1. Viết script trong exec-scripts/
2. Thêm vào telegraf-exec.conf
3. Restart Telegraf Exec

## 🛠️ Maintenance

### Backup
```bash
./scripts/backup.sh
```

### Update
```bash
./scripts/update.sh
```

### Monitoring Health
- Grafana: http://localhost:3000
- InfluxDB: http://localhost:8086
- Prometheus: http://localhost:9090

## 📚 Tài Liệu

- [Hướng dẫn triển khai](docs/DEPLOYMENT.md)
- [Cấu hình chi tiết](docs/CONFIGURATION.md)
- [Xử lý sự cố](docs/TROUBLESHOOTING.md)

## 🤝 Hỗ Trợ

- Email: support@example.com
- Documentation: [Wiki](wiki-link)
- Issues: [GitHub Issues](issues-link)

---
**Version**: 2.0.0  
**License**: MIT  
**Maintainer**: DevOps Team