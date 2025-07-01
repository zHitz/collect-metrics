#!/bin/bash
source "$(dirname "$0")/../.env"
echo "  agents = [\"udp://$TELEGRAF_SNMP_HOST:161\"]" >> "./telegraf.conf"
echo "$TELEGRAF_CONFIG_DIR"
echo "  community = \"$TELEGRAF_SNMP_COMMUNITY\""


snmpget -v 2c -c hissc 172.18.10.2 1.3.6.1.4.1.9.6.1.101.1.9.0