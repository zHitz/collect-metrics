#!/bin/bash

# Script sinh file .env từ .example, random password/token, hỏi cấu hình SNMP
# Ngày: 07/03/2025

EXAMPLE_FILE=".example"
ENV_FILE=".env"

if [ ! -f "$EXAMPLE_FILE" ]; then
    echo "Không tìm thấy file $EXAMPLE_FILE."
    exit 1
fi

cp "$EXAMPLE_FILE" "$ENV_FILE"

# Random password và token
RANDOM_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
RANDOM_TOKEN=$(tr -dc 'a-z0-9' </dev/urandom | head -c 30 | sed 's/.\{6\}/&-/g' | cut -c1-35 | sed 's/-$//')
echo "RANDOM_TOKEN: $RANDOM_TOKEN"
sed -i "s/^INFLUXDB_PASSWORD=.*/INFLUXDB_PASSWORD=$RANDOM_PASS/" "$ENV_FILE"
sed -i "s/^INFLUXDB_TOKEN=.*/INFLUXDB_TOKEN=$RANDOM_TOKEN/" "$ENV_FILE"

# Hỏi cấu hình SNMP
read -p "Bạn có muốn cấu hình SNMP cho Telegraf không? (YES/NO) [NO]: " SNMP_CHOICE
SNMP_CHOICE=${SNMP_CHOICE:-NO}

case "$SNMP_CHOICE" in
    [Yy][Ee][Ss]|[Yy])
        sed -i "s/^TELEGRAF_PLUGINS=.*/TELEGRAF_PLUGINS=cpu,snmp/" "$ENV_FILE"
        sed -i "s/^TELEGRAF_SNMP_HOST=.*/TELEGRAF_SNMP_HOST=172.18.10.2/" "$ENV_FILE"
        sed -i "s/^TELEGRAF_SNMP_COMMUNITY=.*/TELEGRAF_SNMP_COMMUNITY='public'/" "$ENV_FILE"
        sed -i "s/^TELEGRAF_CONFIG_MANUAL=.*/TELEGRAF_CONFIG_MANUAL=NO/" "$ENV_FILE"
        ;;
    *)
        sed -i "s/^TELEGRAF_PLUGINS=.*/TELEGRAF_PLUGINS=cpu/" "$ENV_FILE"
        sed -i "s/^TELEGRAF_CONFIG_MANUAL=.*/TELEGRAF_CONFIG_MANUAL=NO/" "$ENV_FILE"
        ;;
esac

echo "Đã tạo file $ENV_FILE với password và token random." 