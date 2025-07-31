# 🔍 Xử Lý Sự Cố

## 📋 Mục Lục
1. [Vấn Đề Thường Gặp](#vấn-đề-thường-gặp)
2. [Docker & Container Issues](#docker--container-issues)
3. [InfluxDB Issues](#influxdb-issues)
4. [Grafana Issues](#grafana-issues)
5. [Prometheus Issues](#prometheus-issues)
6. [SNMP Issues](#snmp-issues)
7. [Performance Issues](#performance-issues)
8. [Debug Commands](#debug-commands)

## 🚨 Vấn Đề Thường Gặp

### Container không khởi động được

**Triệu chứng**: Container ở trạng thái `Exited` hoặc `Restarting`

**Giải pháp**:
```bash
# Kiểm tra logs
docker compose logs [service-name]

# Kiểm tra chi tiết container
docker inspect [container-name]

# Xem events
docker events --since 10m
```

### Port đã được sử dụng

**Lỗi**: `bind: address already in use`

**Giải pháp**:
```bash
# Tìm process đang dùng port
sudo lsof -i :3000
sudo netstat -tulpn | grep 3000

# Kill process
sudo kill -9 [PID]

# Hoặc đổi port trong .env
GRAFANA_PORT=3001
```

### Không đủ dung lượng

**Lỗi**: `no space left on device`

**Giải pháp**:
```bash
# Kiểm tra dung lượng
df -h
docker system df

# Dọn dẹp Docker
docker system prune -a
docker volume prune
docker image prune -a
```

## 🐳 Docker & Container Issues

### Docker daemon không chạy

**Lỗi**: `Cannot connect to the Docker daemon`

**Giải pháp**:
```bash
# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

### Container bị crash loop

**Giải pháp**:
```bash
# Xem logs chi tiết
docker compose logs --tail=100 -f [service-name]

# Chạy interactive để debug
docker compose run --rm [service-name] /bin/sh

# Check resource limits
docker stats
```

### Network connectivity issues

**Giải pháp**:
```bash
# Kiểm tra network
docker network ls
docker network inspect monitoring-network

# Test connectivity
docker compose exec influxdb ping grafana
docker compose exec grafana curl http://influxdb:8086/health
```

## 💾 InfluxDB Issues

### InfluxDB không start được

**Giải pháp**:
```bash
# Check permissions
ls -la ./data/influxdb

# Fix permissions
sudo chown -R 1000:1000 ./data/influxdb

# Reset InfluxDB
docker compose down influxdb
rm -rf ./data/influxdb/*
docker compose up -d influxdb
```

### Token authentication failed

**Lỗi**: `unauthorized: unauthorized access`

**Giải pháp**:
```bash
# Regenerate token
docker compose exec influxdb influx auth create \
  --org monitoring-org \
  --all-access

# Update token in .env and restart
docker compose restart telegraf-snmp telegraf-exec
```

### Query performance issues

**Giải pháp**:
```bash
# Check cardinality
docker compose exec influxdb influx query \
  'import "influxdata/influxdb/schema"
   schema.measurementCardinality(bucket: "metrics")'

# Optimize retention
docker compose exec influxdb influx bucket update \
  --id [bucket-id] \
  --retention 7d
```

## 📊 Grafana Issues

### Cannot login to Grafana

**Giải pháp**:
```bash
# Reset admin password
docker compose exec grafana grafana-cli admin reset-admin-password newpassword

# Check config
docker compose exec grafana cat /etc/grafana/grafana.ini
```

### Dashboards not loading

**Giải pháp**:
```bash
# Check datasource connectivity
curl -u admin:password http://localhost:3000/api/datasources

# Test datasource
curl -u admin:password -X POST http://localhost:3000/api/datasources/1/health

# Re-provision dashboards
docker compose restart grafana
```

### Plugins not installing

**Giải pháp**:
```bash
# Manual install
docker compose exec grafana grafana-cli plugins install [plugin-id]

# Check installed plugins
docker compose exec grafana grafana-cli plugins ls

# Restart to apply
docker compose restart grafana
```

## 🎯 Prometheus Issues

### Targets showing as DOWN

**Giải pháp**:
```bash
# Check target health
curl http://localhost:9090/api/v1/targets

# Test connectivity from Prometheus container
docker compose exec prometheus wget -O- http://node-exporter:9100/metrics

# Check firewall rules
sudo iptables -L -n | grep 9100
```

### High memory usage

**Giải pháp**:
```bash
# Check TSDB stats
curl http://localhost:9090/api/v1/query?query=prometheus_tsdb_symbol_table_size_bytes

# Reduce retention
docker compose down prometheus
docker compose up -d prometheus
```

### Scrape failures

**Giải pháp**:
```bash
# Check scrape config
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Increase scrape timeout
# Edit prometheus.yml
scrape_configs:
  - job_name: 'slow-targets'
    scrape_timeout: 30s
```

## 📡 SNMP Issues

### SNMP timeout errors

**Giải pháp**:
```bash
# Test SNMP connectivity
docker compose exec telegraf-snmp snmpwalk -v2c -c public 192.168.1.1

# Check MIBs
docker compose exec telegraf-snmp ls /usr/share/snmp/mibs

# Increase timeout in config
timeout = "30s"
retries = 5
```

### MIB not found

**Giải pháp**:
```bash
# Download MIBs
docker compose exec telegraf-snmp download-mibs

# Copy custom MIBs
docker cp custom.mib monitoring-telegraf-snmp:/usr/share/snmp/mibs/
```

### Wrong SNMP data

**Giải pháp**:
```bash
# Debug SNMP queries
docker compose exec telegraf-snmp telegraf --debug \
  --config /etc/telegraf/telegraf.conf \
  --test

# Check OID translation
docker compose exec telegraf-snmp snmptranslate -On IF-MIB::ifInOctets
```

## 🚀 Performance Issues

### High CPU usage

**Diagnosis**:
```bash
# Find high CPU containers
docker stats --no-stream

# Check process inside container
docker compose exec [service] top
```

**Solutions**:
1. Increase scrape intervals
2. Reduce metric cardinality
3. Add resource limits
4. Optimize queries

### High memory usage

**Diagnosis**:
```bash
# Memory per container
docker ps -q | xargs docker stats --no-stream

# Check memory inside container
docker compose exec [service] cat /proc/meminfo
```

**Solutions**:
```yaml
# Add swap limit
deploy:
  resources:
    limits:
      memory: 2g
    reservations:
      memory: 1g
```

### Slow queries

**InfluxDB optimization**:
```bash
# Enable query logging
docker compose exec influxdb influx config set \
  --log-level debug

# Check slow queries
docker compose logs influxdb | grep "query took"
```

**Prometheus optimization**:
- Use recording rules
- Optimize PromQL queries
- Increase query timeout

## 🛠️ Debug Commands

### General debugging
```bash
# System resources
free -h
df -h
iostat -x 1

# Docker debugging
docker version
docker info
docker compose version
```

### Service-specific debugging

**InfluxDB**:
```bash
# Health check
curl http://localhost:8086/health

# Metrics
curl http://localhost:8086/metrics

# Query data
docker compose exec influxdb influx query 'from(bucket:"metrics") |> range(start:-1h)'
```

**Grafana**:
```bash
# API health
curl http://localhost:3000/api/health

# List datasources
curl -u admin:password http://localhost:3000/api/datasources

# List dashboards
curl -u admin:password http://localhost:3000/api/search
```

**Prometheus**:
```bash
# Config check
curl http://localhost:9090/api/v1/status/config

# Target status
curl http://localhost:9090/api/v1/targets

# TSDB status
curl http://localhost:9090/api/v1/status/tsdb
```

### Log analysis
```bash
# All logs
docker compose logs

# Specific service with timestamps
docker compose logs -t --since 1h grafana

# Follow logs
docker compose logs -f

# Export logs
docker compose logs > monitoring-logs.txt
```

### Container inspection
```bash
# Full container details
docker inspect monitoring-influxdb

# Network details
docker inspect monitoring-influxdb | jq '.[0].NetworkSettings'

# Mount points
docker inspect monitoring-influxdb | jq '.[0].Mounts'

# Environment variables
docker inspect monitoring-influxdb | jq '.[0].Config.Env'
```

## 🆘 Emergency Recovery

### Full system recovery
```bash
#!/bin/bash
# Emergency recovery script

# Stop all containers
docker compose down

# Backup current data
tar -czf emergency-backup-$(date +%Y%m%d-%H%M%S).tar.gz ./data

# Clear all data
rm -rf ./data/*

# Recreate from scratch
./scripts/deploy.sh
```

### Service-specific recovery
```bash
# Recover single service
docker compose stop [service]
docker compose rm -f [service]
docker compose up -d [service]
```

## 📞 Getting Help

Nếu không thể tự giải quyết:

1. **Thu thập thông tin**:
   ```bash
   # System info
   uname -a
   docker version
   docker compose version
   
   # Logs
   docker compose logs > full-logs.txt
   
   # Configuration
   cat .env | grep -v PASSWORD > config-info.txt
   ```

2. **Tạo issue với**:
   - Mô tả chi tiết vấn đề
   - Steps to reproduce
   - Logs và error messages
   - System information

3. **Community resources**:
   - GitHub Issues
   - Stack Overflow
   - Docker Forums
   - Grafana Community