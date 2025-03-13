#!/bin/bash

# Update and install Docker if not installed

# Create necessary directories
mkdir -p ~/influxdb-telegraf-deploy/config
mkdir -p ~/influxdb-telegraf-deploy/scripts

# Create .env file
cat <<EOF > ~/influxdb-telegraf-deploy/.env
# InfluxDB Config
INFLUXDB_VERSION=2.7.0
INFLUXDB_USERNAME=admin
INFLUXDB_PASSWORD=SecureP@ssw0rd2025
INFLUXDB_ORG=ProdMonitoring
INFLUXDB_BUCKET=ServerMetrics
INFLUXDB_TOKEN=xyz123-abc456-def789-ghi012-jkl345
INFLUXDB_DATA_DIR=/opt/influxdb/data

# Telegraf Config
TELEGRAF_VERSION=1.25.0
TELEGRAF_CONFIG_DIR=/etc/telegraf

# Network Config
NETWORK_NAME=influxdb-telegraf-net

# Docker Resource Limits
MEMORY_LIMIT=512m
CPU_LIMIT=1
EOF

# Create docker-compose.yml
cat <<EOF > ~/influxdb-telegraf-deploy/docker-compose.yml
version: '3.8'

services:
  influxdb:
    image: influxdb:\${INFLUXDB_VERSION}
    container_name: influxdb
    networks:
      - influxdb-telegraf-net
    volumes:
      - \${INFLUXDB_DATA_DIR}:/var/lib/influxdb2
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=\${INFLUXDB_USERNAME}
      - DOCKER_INFLUXDB_INIT_PASSWORD=\${INFLUXDB_PASSWORD}
      - DOCKER_INFLUXDB_INIT_ORG=\${INFLUXDB_ORG}
      - DOCKER_INFLUXDB_INIT_BUCKET=\${INFLUXDB_BUCKET}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=\${INFLUXDB_TOKEN}
    restart: unless-stopped

  telegraf:
    image: telegraf:\${TELEGRAF_VERSION}
    container_name: telegraf
    networks:
      - influxdb-telegraf-net
    volumes:
      - \${TELEGRAF_CONFIG_DIR}/telegraf.conf:/etc/telegraf/telegraf.conf
    environment:
      - INFLUXDB_TOKEN=\${INFLUXDB_TOKEN}
      - INFLUXDB_ORG=\${INFLUXDB_ORG}
      - INFLUXDB_BUCKET=\${INFLUXDB_BUCKET}
    restart: unless-stopped

networks:
  influxdb-telegraf-net:
    driver: bridge
EOF

# Create telegraf.conf
cat <<EOF > ~/influxdb-telegraf-deploy/config/telegraf.conf
[agent]
  interval = "10s"
  flush_interval = "10s"

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "\${INFLUXDB_TOKEN}"
  organization = "\${INFLUXDB_ORG}"
  bucket = "\${INFLUXDB_BUCKET}"

[[inputs.snmp]]
  agents = ["udp://<SNMP_DEVICE_IP>:161"]
  version = 2
  community = "public"

  [[inputs.snmp.field]]
    name = "sysUpTime"
    oid = "1.3.6.1.2.1.1.3.0"
    conversion = "int"
EOF

# Start services
cd ~/influxdb-telegraf-deploy
sudo docker-compose --env-file .env up -d
