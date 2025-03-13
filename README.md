# InfluxDB and Telegraf Deployment

A professional, modular, and production-ready deployment solution for InfluxDB and Telegraf using Docker Compose. This project automates the setup of a monitoring stack to collect system metrics (e.g., CPU, memory, disk) and SNMP data, store them in InfluxDB, and provides debug scripts to validate the setup.

## Features

- **Docker Compose-Based**: Deploys InfluxDB and Telegraf as containerized services with a single command.
- **Modular Design**: Separates deployment logic into scripts for easy maintenance and extension.
- **Configurable Plugins**: Supports Telegraf plugins (`cpu`, `memory`, `disk`, `snmp`) via environment variables.
- **SNMP Support**: Includes automatic MIB file handling for SNMP monitoring.
- **Debug Tools**: Built-in scripts to test and validate Telegraf and InfluxDB configurations.
- **Production-Ready**: Resource limits, automatic restarts, and logging for stability.

## Project Structure

```bash
influxdb-telegraf-deploy/
├── .env                   # Environment variables for configuration
├── docker-compose.yml     # Docker Compose service definitions
├── scripts/               # Deployment scripts
│   ├── deploy.sh          # Main deployment script
│   ├── install_docker.sh  # Installs Docker and Docker Compose
│   ├── setup_network.sh   # Sets up Docker network
│   └── config_telegraf.sh # Generates Telegraf configuration
├── config/                # Telegraf configuration directory
│   └── telegraf.conf      # Generated Telegraf config file
├── debug/                 # Debug and test scripts
│   ├── test_telegraf.sh   # Tests Telegraf functionality
│   └── test_influxdb.sh   # Tests InfluxDB functionality
└── mibs/                  # SNMP MIB files
    ├── IF-MIB.txt         # MIB for network interfaces
    └── SNMPv2-MIB.txt     # MIB for SNMPv2 objects
```

## Prerequisites

- **OS**: Ubuntu (tested on 20.04/22.04)
- **Dependencies**: 
  - Docker
  - Docker Compose (v2.24.7 or later recommended)
- **Network Access**: For SNMP, ensure devices are reachable (e.g., `172.18.10.2:161`).

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://https://github.com/zHitz/Collect-Metrics.git
   cd influxdb-telegraf-deploy
   ```
2. **Set Up Permissions**:
   ```bash
   chmod +x scripts/*.sh debug/*.sh
   ```

3. **Configure Environment Variables**:
   Edit `.env` to customize your setup:
   ```bash
   nano .env
   ```
   Example `.env`:
   ```
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
   TELEGRAF_PLUGINS=cpu,memory,disk,snmp

   # Network Config
   NETWORK_NAME=influxdb-telegraf-net

   # Resource Limits
   MEMORY_LIMIT=512m
   CPU_LIMIT=1

   # Debug Option
   DEBUG=no
   ```

## Deployment

Run the main deployment script:
```bash
sudo ./scripts/deploy.sh
```

- **What it does**:
  - Installs Docker and Docker Compose if not present.
  - Creates a Docker network (`influxdb-telegraf-net`).
  - Generates Telegraf configuration with specified plugins.
  - Downloads SNMP MIB files (if `snmp` is enabled).
  - Deploys InfluxDB and Telegraf containers.

- **Output**: Check container status and logs after deployment:
  ```
  docker ps -a
  docker logs telegraf
  ```

## Debugging

Enable debugging by setting `DEBUG=yes` in `.env`, then redeploy:
```bash
sudo ./scripts/deploy.sh
```

This runs additional tests:
- `debug/test_telegraf.sh`: Verifies SNMP, logs, and network connectivity.
- `debug/test_influxdb.sh`: Checks databases, measurements, and data insertion.

Run tests manually:
```bash
sudo ./debug/test_telegraf.sh
sudo ./debug/test_influxdb.sh
```

## Configuration

### Telegraf Plugins
Edit `TELEGRAF_PLUGINS` in `.env` to enable/disable plugins:
- `cpu`: Collects CPU metrics.
- `memory`: Collects memory usage.
- `disk`: Collects disk usage.
- `snmp`: Collects SNMP data (requires MIB files).

Example:
```
TELEGRAF_PLUGINS=cpu,snmp
```

### SNMP Setup
- Ensure SNMP devices are accessible (e.g., `172.18.10.2:161`).
- Customize SNMP configuration in `scripts/config_telegraf.sh` under the `snmp` case (e.g., agents, community string).

### MIB Files
SNMP requires MIB files, automatically downloaded to `mibs/` during deployment if `snmp` is enabled. To add custom MIBs:
```bash
cp your-mib-file.txt mibs/
sudo chmod 644 mibs/your-mib-file.txt
```

## Accessing InfluxDB

- **URL**: `http://localhost:8086`
- **Credentials**: Use `INFLUXDB_USERNAME` and `INFLUXDB_PASSWORD` from `.env`.
- **Token**: Use `INFLUXDB_TOKEN` for API access.
- **Bucket**: Data is stored in the bucket specified by `INFLUXDB_BUCKET`.

## Troubleshooting

- **Telegraf SNMP Errors**:
  - Check `docker logs telegraf` for MIB-related errors.
  - Verify MIB files in `mibs/` and container (`docker exec -it telegraf ls /usr/share/snmp/mibs`).
- **InfluxDB Connection**:
  - Ensure `influxdb` container is running (`docker ps`).
  - Check logs: `docker logs influxdb`.
- **Network Issues**:
  - Verify network: `docker network ls | grep influxdb-telegraf-net`.

## Extending the Project

- **Add Grafana**: Extend `docker-compose.yml` to include Grafana for visualization.
- **Custom Plugins**: Modify `scripts/config_telegraf.sh` to support additional Telegraf plugins.
- **Backup**: Add volume backups for `${INFLUXDB_DATA_DIR}`.

## Contributing

Feel free to submit issues or pull requests on GitHub. Contributions are welcome!

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---
Created with ❤️ by Hitz on March 12, 2025
```
