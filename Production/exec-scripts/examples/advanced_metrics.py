#!/usr/bin/env python3

"""
Advanced Metrics Collection Script
Outputs metrics in JSON format for Telegraf
"""

import json
import os
import subprocess
import time
import socket

def get_system_metrics():
    """Collect system-level metrics"""
    metrics = []
    
    # TCP connection states
    try:
        output = subprocess.check_output(['ss', '-tan'], text=True)
        states = {'ESTABLISHED': 0, 'TIME_WAIT': 0, 'CLOSE_WAIT': 0, 'LISTEN': 0}
        
        for line in output.splitlines()[1:]:  # Skip header
            parts = line.split()
            if len(parts) >= 1:
                state = parts[0]
                if state in states:
                    states[state] += 1
        
        metrics.append({
            "measurement": "tcp_connections",
            "tags": {
                "host": socket.gethostname()
            },
            "fields": states,
            "time": int(time.time())
        })
    except Exception as e:
        print(f"Error collecting TCP stats: {e}", file=sys.stderr)
    
    # Network interface statistics
    try:
        with open('/proc/net/dev', 'r') as f:
            lines = f.readlines()[2:]  # Skip headers
            
        for line in lines:
            if ':' in line:
                parts = line.split(':')
                interface = parts[0].strip()
                stats = parts[1].split()
                
                if interface not in ['lo']:  # Skip loopback
                    metrics.append({
                        "measurement": "network_interface",
                        "tags": {
                            "host": socket.gethostname(),
                            "interface": interface
                        },
                        "fields": {
                            "rx_bytes": int(stats[0]),
                            "rx_packets": int(stats[1]),
                            "rx_errors": int(stats[2]),
                            "rx_dropped": int(stats[3]),
                            "tx_bytes": int(stats[8]),
                            "tx_packets": int(stats[9]),
                            "tx_errors": int(stats[10]),
                            "tx_dropped": int(stats[11])
                        },
                        "time": int(time.time())
                    })
    except Exception as e:
        print(f"Error collecting network stats: {e}", file=sys.stderr)
    
    return metrics

def get_process_metrics():
    """Collect process-specific metrics"""
    metrics = []
    
    # Top CPU consuming processes
    try:
        output = subprocess.check_output(
            ['ps', 'aux', '--sort=-pcpu'], 
            text=True
        )
        lines = output.splitlines()[1:6]  # Top 5 processes
        
        for i, line in enumerate(lines):
            parts = line.split(None, 10)
            if len(parts) >= 11:
                metrics.append({
                    "measurement": "top_processes",
                    "tags": {
                        "host": socket.gethostname(),
                        "rank": i + 1,
                        "process": parts[10][:50]  # Limit process name length
                    },
                    "fields": {
                        "cpu_percent": float(parts[2]),
                        "mem_percent": float(parts[3]),
                        "pid": int(parts[1])
                    },
                    "time": int(time.time())
                })
    except Exception as e:
        print(f"Error collecting process stats: {e}", file=sys.stderr)
    
    return metrics

def get_service_health():
    """Check health of critical services"""
    metrics = []
    
    # Define services to check
    services = [
        {"name": "docker", "port": None, "process": "dockerd"},
        {"name": "ssh", "port": 22, "process": "sshd"},
        {"name": "nginx", "port": 80, "process": "nginx"},
    ]
    
    for service in services:
        is_running = 0
        
        # Check if process is running
        try:
            subprocess.check_output(['pgrep', service['process']])
            is_running = 1
        except subprocess.CalledProcessError:
            is_running = 0
        
        # Check if port is listening (if applicable)
        port_listening = 0
        if service['port'] and is_running:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(1)
                result = sock.connect_ex(('localhost', service['port']))
                sock.close()
                port_listening = 1 if result == 0 else 0
            except:
                port_listening = 0
        
        metrics.append({
            "measurement": "service_health",
            "tags": {
                "host": socket.gethostname(),
                "service": service['name']
            },
            "fields": {
                "is_running": is_running,
                "port_listening": port_listening
            },
            "time": int(time.time())
        })
    
    return metrics

def main():
    """Main function to collect and output all metrics"""
    all_metrics = []
    
    # Collect all metrics
    all_metrics.extend(get_system_metrics())
    all_metrics.extend(get_process_metrics())
    all_metrics.extend(get_service_health())
    
    # Output as JSON
    for metric in all_metrics:
        print(json.dumps(metric))

if __name__ == "__main__":
    import sys
    main()