#!/bin/bash
source "$(dirname "$0")/../.env"
echo "  agents = [\"udp://$TELEGRAF_SNMP_HOST:161\"]" >> "./telegraf.conf"
echo "$TELEGRAF_CONFIG_DIR"
echo "  community = \"$TELEGRAF_SNMP_COMMUNITY\""