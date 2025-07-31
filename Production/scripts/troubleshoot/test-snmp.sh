#!/bin/bash

################################################################################
# Test SNMP Configuration Script
# This script tests SNMP connectivity and configuration
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
load_env() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
        log_success "Environment variables loaded"
    else
        log_error ".env file not found!"
        exit 1
    fi
}

# Check if snmpwalk is installed
check_snmp_tools() {
    log_info "Checking SNMP tools..."
    
    if command -v snmpwalk &> /dev/null; then
        log_success "snmpwalk is installed"
    else
        log_warning "snmpwalk not found. Installing SNMP tools..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y snmp
        elif command -v yum &> /dev/null; then
            sudo yum install -y net-snmp-utils
        else
            log_error "Cannot install SNMP tools automatically"
            log_info "Please install snmpwalk manually"
            return 1
        fi
    fi
}

# Test SNMP connectivity
test_snmp_connectivity() {
    log_info "Testing SNMP connectivity..."
    
    if [ -z "${TELEGRAF_SNMP_AGENTS:-}" ]; then
        log_warning "TELEGRAF_SNMP_AGENTS not set"
        return 1
    fi
    
    # Parse SNMP agents
    IFS=',' read -ra AGENTS <<< "$TELEGRAF_SNMP_AGENTS"
    local success_count=0
    local total_count=0
    
    for agent in "${AGENTS[@]}"; do
        IFS=':' read -ra PARTS <<< "$agent"
        if [ ${#PARTS[@]} -eq 4 ]; then
            local name="${PARTS[0]}"
            local host="${PARTS[1]}"
            local port="${PARTS[2]}"
            local community="${PARTS[3]}"
            
            total_count=$((total_count + 1))
            log_info "Testing SNMP connectivity to $name ($host:$port)..."
            
            # Test SNMP connectivity
            if timeout 10 snmpwalk -v2c -c "$community" "$host:$port" .1.3.6.1.2.1.1.1.0 &> /dev/null; then
                log_success "✅ $name ($host:$port) - SNMP accessible"
                success_count=$((success_count + 1))
                
                # Get system description
                local sysdescr=$(snmpwalk -v2c -c "$community" "$host:$port" .1.3.6.1.2.1.1.1.0 2>/dev/null | head -1)
                if [ -n "$sysdescr" ]; then
                    log_info "   System: $sysdescr"
                fi
            else
                log_error "❌ $name ($host:$port) - SNMP not accessible"
            fi
        else
            log_warning "Invalid agent format: $agent"
        fi
    done
    
    echo ""
    log_info "SNMP Connectivity Summary:"
    log_info "  Total agents: $total_count"
    log_info "  Successful: $success_count"
    log_info "  Failed: $((total_count - success_count))"
    
    if [ $success_count -eq $total_count ] && [ $total_count -gt 0 ]; then
        log_success "All SNMP agents are accessible!"
        return 0
    elif [ $success_count -gt 0 ]; then
        log_warning "Some SNMP agents are not accessible"
        return 1
    else
        log_error "No SNMP agents are accessible"
        return 1
    fi
}

# Show SNMP configuration
show_snmp_config() {
    echo ""
    echo "======================================"
    echo "SNMP Configuration"
    echo "======================================"
    echo ""
    
    if [ "${ENABLE_SNMP:-false}" = "true" ]; then
        echo "🔹 SNMP Monitoring: ENABLED"
        echo "  📊 SNMP Version: ${TELEGRAF_SNMP_VERSION:-2}"
        echo "  🔑 Community: ${TELEGRAF_SNMP_COMMUNITY:-public}"
        echo "  ⏱️  Interval: ${TELEGRAF_SNMP_INTERVAL:-30s}"
        echo ""
        
        if [ -n "${TELEGRAF_SNMP_AGENTS:-}" ]; then
            echo "📋 SNMP Agents:"
            IFS=',' read -ra AGENTS <<< "$TELEGRAF_SNMP_AGENTS"
            for agent in "${AGENTS[@]}"; do
                IFS=':' read -ra PARTS <<< "$agent"
                if [ ${#PARTS[@]} -eq 4 ]; then
                    echo "  • ${PARTS[0]}: ${PARTS[1]}:${PARTS[2]} (${PARTS[3]})"
                fi
            done
        else
            echo "⚠️  No SNMP agents configured"
        fi
    else
        echo "🔹 SNMP Monitoring: DISABLED"
    fi
    echo ""
}

# Test Telegraf SNMP configuration
test_telegraf_config() {
    log_info "Testing Telegraf SNMP configuration..."
    
    local config_file="$PROJECT_ROOT/configs/telegraf/telegraf-snmp.conf"
    
    if [ ! -f "$config_file" ]; then
        log_error "Telegraf SNMP config file not found: $config_file"
        return 1
    fi
    
    # Check if agents are configured
    local agents_line=$(grep "^  agents = " "$config_file" || true)
    if [ -n "$agents_line" ]; then
        log_success "SNMP agents configured in Telegraf"
        log_info "  $agents_line"
    else
        log_error "No SNMP agents found in Telegraf config"
        return 1
    fi
    
    # Test Telegraf config syntax
    if docker run --rm -v "$config_file:/etc/telegraf/telegraf.conf:ro" telegraf:${TELEGRAF_VERSION:-1.27.0} telegraf --test --config /etc/telegraf/telegraf.conf &> /dev/null; then
        log_success "Telegraf SNMP configuration is valid"
    else
        log_error "Telegraf SNMP configuration has errors"
        return 1
    fi
}

# Show troubleshooting tips
show_troubleshooting() {
    echo ""
    echo "======================================"
    echo "SNMP Troubleshooting Tips"
    echo "======================================"
    echo ""
    echo "If SNMP connectivity fails:"
    echo "  1. Check if SNMP is enabled on the device"
    echo "  2. Verify the community string is correct"
    echo "  3. Check firewall rules (UDP port 161)"
    echo "  4. Verify the device IP address is reachable"
    echo "  5. Test with: snmpwalk -v2c -c community device_ip .1.3.6.1.2.1.1.1.0"
    echo ""
    echo "Common SNMP community strings:"
    echo "  • public (default)"
    echo "  • private"
    echo "  • cisco (Cisco devices)"
    echo "  • admin (some devices)"
    echo ""
}

# Main function
main() {
    echo ""
    echo "======================================"
    echo "SNMP Configuration Test"
    echo "======================================"
    echo ""
    
    # Load environment variables
    load_env
    
    # Show SNMP configuration
    show_snmp_config
    
    # Check if SNMP is enabled
    if [ "${ENABLE_SNMP:-false}" != "true" ]; then
        log_info "SNMP monitoring is disabled"
        exit 0
    fi
    
    # Check SNMP tools
    check_snmp_tools
    
    # Test SNMP connectivity
    test_snmp_connectivity
    
    # Test Telegraf configuration
    test_telegraf_config
    
    # Show troubleshooting tips
    show_troubleshooting
    
    echo ""
    log_success "SNMP test completed!"
    echo ""
}

# Run main function
main "$@" 