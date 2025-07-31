#!/bin/bash

# Basic Metrics Collection Script
# Output format: InfluxDB Line Protocol

# Get hostname
HOSTNAME=$(hostname)

# Get load average
LOAD_1=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | xargs)
LOAD_5=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $2}' | xargs)
LOAD_15=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $3}' | xargs)

# Get uptime in seconds
UPTIME_SECONDS=$(cat /proc/uptime | awk '{print $1}')

# Get number of processes
PROCESS_COUNT=$(ps aux | wc -l)

# Get logged in users
USER_COUNT=$(who | wc -l)

# Output metrics in InfluxDB line protocol format
echo "system_info,host=$HOSTNAME load_1min=$LOAD_1,load_5min=$LOAD_5,load_15min=$LOAD_15,uptime_seconds=$UPTIME_SECONDS,process_count=$PROCESS_COUNT,user_count=$USER_COUNT"

# Get disk usage for root partition
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_AVAILABLE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')

echo "disk_usage,host=$HOSTNAME,partition=root usage_percent=$DISK_USAGE,available_gb=$DISK_AVAILABLE"

# Get memory info
TOTAL_MEM=$(free -b | grep Mem | awk '{print $2}')
USED_MEM=$(free -b | grep Mem | awk '{print $3}')
FREE_MEM=$(free -b | grep Mem | awk '{print $4}')
CACHED_MEM=$(free -b | grep Mem | awk '{print $6}')

echo "memory_usage,host=$HOSTNAME total=$TOTAL_MEM,used=$USED_MEM,free=$FREE_MEM,cached=$CACHED_MEM"