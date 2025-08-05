# Monitoring System Manager

## Giới thiệu

`manager.sh` là một script quản lý tổng hợp cho hệ thống monitoring, cung cấp giao diện menu tương tác để quản lý toàn bộ stack monitoring một cách dễ dàng.

## Tính năng chính

### 1. 📈 System Status Overview
- Kiểm tra trạng thái tất cả services
- Xem resource usage (CPU, Memory)
- Hiển thị các URL truy cập

### 2. 🔧 Service Management
- Start/Stop/Restart tất cả services
- Restart service cụ thể
- Xem logs của từng service
- Execute commands trong containers

### 3. ⚙️ Configuration Management
- Xem cấu hình hiện tại
- Chỉnh sửa biến môi trường
- Regenerate configurations
- Validate cấu hình
- Enable/Disable modules (SNMP, Custom Scripts, Alerting, Portainer)
- Update passwords và tokens

### 4. 🔍 Troubleshooting
- Fix permissions tự động
- Test SNMP connectivity
- Test Docker Compose profiles
- Xem recent errors
- Check disk usage
- Test network connectivity
- Reset services

### 5. 💾 Backup & Restore
- Tạo full backup
- List backups có sẵn
- Restore từ backup
- Xóa backups cũ
- Schedule automatic backups

### 6. 📊 Data Management
- Xem thống kê data usage
- Clean up dữ liệu cũ
- Export/Import metrics
- Optimize databases

### 7. ⚡ Quick Actions
- Health check tất cả services
- Update Docker images
- Generate system report
- Mở Grafana trong browser
- Test tất cả endpoints
- Clear logs

## Cách sử dụng

### Chạy script

```bash
# Từ thư mục root của project
./scripts/manager.sh

# Hoặc từ thư mục scripts
cd scripts
./manager.sh
```

### Navigation

- Sử dụng số để chọn menu option
- Nhấn `0` để quay lại menu trước
- Nhấn `Enter` để tiếp tục sau mỗi action

### Yêu cầu

- Docker và Docker Compose đã được cài đặt
- Chạy với user có quyền Docker (không phải root)
- File `.env` đã được cấu hình

## Ví dụ sử dụng

### 1. Kiểm tra trạng thái hệ thống

```
Main Menu > 1) System Status Overview
```

Hiển thị:
- Trạng thái các services (Running/Stopped)
- Resource usage
- Access URLs

### 2. Enable SNMP monitoring

```
Main Menu > 3) Configuration Management > 5) Enable/Disable modules
```

Chọn module SNMP và restart services.

### 3. Tạo backup

```
Main Menu > 5) Backup & Restore > 1) Create full backup
```

Backup sẽ được lưu trong thư mục `backups/`.

### 4. Fix permission issues

```
Main Menu > 4) Troubleshooting > 1) Check and fix permissions
```

Tự động fix permissions cho tất cả data directories.

### 5. Xem logs của service

```
Main Menu > 2) Service Management > 5) View service logs
```

Nhập tên service và số dòng muốn xem.

## Tips

1. **Quick Health Check**: Sử dụng Quick Actions > Health check để kiểm tra nhanh tất cả services

2. **Backup định kỳ**: Schedule automatic backups qua crontab

3. **Monitor disk usage**: Thường xuyên kiểm tra disk usage trong Troubleshooting menu

4. **Update images**: Update Docker images định kỳ qua Quick Actions

5. **Export data**: Export metrics data trước khi upgrade hoặc migrate

## Troubleshooting Script Issues

### Script không chạy được

```bash
# Check permissions
ls -la scripts/manager.sh

# Fix permissions
chmod +x scripts/manager.sh
```

### Không tìm thấy Docker

```bash
# Install Docker
./scripts/install-docker.sh
```

### Environment variables không load

```bash
# Check .env file exists
ls -la .env

# Copy from template if needed
cp .env.example .env
```

## Advanced Usage

### Custom modifications

Bạn có thể mở rộng script bằng cách:

1. Thêm menu options mới trong các functions `*_menu()`
2. Thêm functions mới cho custom actions
3. Modify colors và formatting trong phần định nghĩa colors

### Integration với CI/CD

Script có thể được sử dụng trong automation:

```bash
# Non-interactive backup
echo "1" | ./scripts/manager.sh

# Generate report automatically
./scripts/manager.sh <<EOF
7
3
0
0
EOF
```

## Support

Nếu gặp vấn đề:

1. Check logs: `docker compose logs`
2. Run troubleshooting menu
3. Generate system report
4. Check documentation trong `docs/`