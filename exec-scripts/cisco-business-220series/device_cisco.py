import subprocess
import time
import os
import re
import sys
import threading
import pexpect
from concurrent.futures import ThreadPoolExecutor, as_completed
from dotenv import load_dotenv

# --- Thông tin kết nối và xác thực ---
# Load môi trường từ file .env cùng thư mục với file này
script_dir = os.path.dirname(os.path.abspath(__file__))
env_path = os.path.join(script_dir, '.env')
print(f"Looking for .env file at: {env_path}", file=sys.stderr)
print(f".env file exists: {os.path.exists(env_path)}", file=sys.stderr)
load_dotenv(env_path)

# Load cấu hình thiết bị từ biến môi trường
def load_device_configs():
    """Load tất cả cấu hình thiết bị từ biến môi trường"""
    devices = []
    device_num = 1
    
    while True:
        host_key = f'CISCO_HOST_{device_num}'
        host = os.getenv(host_key)
        
        if not host:
            break
            
        device_config = {
            'hostname': host,
            'port': int(os.getenv(f'CISCO_PORT_{device_num}', 22)),
            'username': os.getenv(f'CISCO_USERNAME_{device_num}'),
            'password': os.getenv(f'CISCO_PASSWORD_{device_num}'),
            'enable_password': os.getenv(f'CISCO_ENABLE_PASSWORD_{device_num}', '').strip("'\"") or None
        }
        
        # Validate required fields
        if device_config['username'] and device_config['password']:
            devices.append(device_config)
            print(f"Loaded device config for {host}", file=sys.stderr)
            print(f"  Username: {device_config['username']}", file=sys.stderr)
            print(f"  Password: {'*' * len(device_config['password']) if device_config['password'] else 'None'}", file=sys.stderr)
            print(f"  Enable password: {'*' * len(device_config['enable_password']) if device_config['enable_password'] else 'None'}", file=sys.stderr)
        else:
            print(f"Warning: Incomplete config for device {device_num}, skipping", file=sys.stderr)
            print(f"  Username present: {bool(device_config['username'])}", file=sys.stderr)
            print(f"  Password present: {bool(device_config['password'])}", file=sys.stderr)
            
        device_num += 1
    
    return devices

# --- Lớp xử lý kết nối và tương tác SSH bằng pexpect ---
class CiscoSSHClient:
    def __init__(self, hostname, port, username, password, enable_password):
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.enable_password = enable_password if enable_password else None
        self.connection = None

    def connect_and_login(self):
        """Thiết lập kết nối SSH bằng pexpect - giống SSH thủ công."""
        try:
            print(f"Attempting to connect to {self.hostname} using pexpect...", file=sys.stderr)
            
            # Create SSH connection using pexpect
            ssh_command = f'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {self.username}@{self.hostname}'
            print(f"SSH command: {ssh_command}", file=sys.stderr)
            
            self.connection = pexpect.spawn(ssh_command, timeout=30)
            
            # Log all interaction for debugging
            self.connection.logfile_read = sys.stderr.buffer
            
            index = self.connection.expect([
                'Press <Enter> to continue',
                'Welcome to Layer 2 Managed Switch',
                'Username:',
                'Password:',
                pexpect.TIMEOUT,
                pexpect.EOF
            ], timeout=30)
            
            print(f"Initial expect index: {index}", file=sys.stderr)
            
            if index in [0, 1]:  # Welcome message
                print(f"Received welcome message, sending Enter", file=sys.stderr)
                self.connection.send('\n')
                
                # Wait for username prompt
                index = self.connection.expect(['Username:', pexpect.TIMEOUT], timeout=10)
                if index == 0:
                    print(f"Sending username: {self.username}", file=sys.stderr)
                    self.connection.sendline(self.username)
                    
                    # Wait for password prompt
                    index = self.connection.expect(['Password:', pexpect.TIMEOUT], timeout=10)
                    if index == 0:
                        print(f"Sending password", file=sys.stderr)
                        self.connection.sendline(self.password)
                    else:
                        print(f"Password prompt timeout", file=sys.stderr)
                        return False
                else:
                    print(f"Username prompt timeout", file=sys.stderr)
                    return False
                    
            elif index == 2:  # Direct username prompt
                print(f"Sending username: {self.username}", file=sys.stderr)
                self.connection.sendline(self.username)
                
                # Wait for password prompt
                index = self.connection.expect(['Password:', pexpect.TIMEOUT], timeout=10)
                if index == 0:
                    print(f"Sending password", file=sys.stderr)
                    self.connection.sendline(self.password)
                else:
                    print(f"Password prompt timeout", file=sys.stderr)
                    return False
                    
            elif index == 3:  # Direct password prompt
                print(f"Sending password", file=sys.stderr)
                self.connection.sendline(self.password)
                
            else:
                print(f"Unexpected response or timeout during initial connection", file=sys.stderr)
                return False
            
            # Wait for shell prompt
            print(f"Waiting for shell prompt...", file=sys.stderr)
            index = self.connection.expect(['#', '>', pexpect.TIMEOUT], timeout=15)
            
            if index == 1:  # User mode prompt '>'
                print(f"In user mode, entering enable mode", file=sys.stderr)
                self.connection.sendline('enable')
                
                # Check if enable password is required
                index = self.connection.expect(['Password:', '#', pexpect.TIMEOUT], timeout=10)
                if index == 0:  # Enable password required
                    if self.enable_password:
                        print(f"Sending enable password", file=sys.stderr)
                        self.connection.sendline(self.enable_password)
                        
                        # Wait for privileged prompt
                        index = self.connection.expect(['#', pexpect.TIMEOUT], timeout=10)
                        if index != 0:
                            print(f"Failed to enter privileged mode after enable password", file=sys.stderr)
                            return False
                    else:
                        print(f"Enable password required but not provided", file=sys.stderr)
                        return False
                elif index == 1:  # Already in privileged mode
                    print(f"Enable successful without password", file=sys.stderr)
                else:
                    print(f"Enable command timeout", file=sys.stderr)
                    return False
                    
            elif index == 0:  # Already in privileged mode
                print(f"Already in privileged mode", file=sys.stderr)
            else:
                print(f"Shell prompt timeout", file=sys.stderr)
                return False
            
            print(f"Successfully connected and authenticated to {self.hostname}", file=sys.stderr)
            return True
            
        except Exception as e:
            print(f"Error connecting to {self.hostname}: {e}", file=sys.stderr)
            return False

    def send_command(self, command, timeout=10):
        """Gửi lệnh và nhận kết quả."""
        if not self.connection:
            print(f"Error: No connection available to execute command '{command}'.", file=sys.stderr)
            return None
            
        try:
            print(f"Sending command: {command}", file=sys.stderr)
            self.connection.sendline(command)
            
            # Wait for command to complete and return to prompt
            index = self.connection.expect(['#', pexpect.TIMEOUT], timeout=timeout)
            if index == 0:
                # Get the output
                output = self.connection.before.decode('utf-8', errors='ignore')
                
                # Clean up the output
                lines = output.split('\n')
                clean_lines = []
                for line in lines:
                    line = line.strip()
                    if line and not line.startswith(command) and line != command:
                        clean_lines.append(line)
                
                result = '\n'.join(clean_lines)
                print(f"Command output received ({len(result)} chars)", file=sys.stderr)
                return result
            else:
                print(f"Command timeout for: {command}", file=sys.stderr)
                return None
                
        except Exception as e:
            print(f"Error executing command '{command}': {e}", file=sys.stderr)
            return None

    def close(self):
        """Đóng kết nối SSH."""
        if self.connection:
            try:
                self.connection.close()
            except:
                pass

# --- Hàm thu thập metrics và format cho Telegraf ---

def get_memory_stats(ssh_client, host):
    """Thu thập Memory (RAM) metrics từ 'show memory statistics'."""
    raw_output = ssh_client.send_command("show memory statistics")
    metrics = []
    timestamp = int(time.time() * 1e9)

    if raw_output:
        print(f"Memory command output for {host}:\n{raw_output}", file=sys.stderr)
        
        # Parse theo kiểu Linux free - sử dụng "-/+ buffers/cache" line
        # Format: "-/+ buffers/cache:          90756       165024"
        buffers_cache_pattern = r"-/\+ buffers/cache:\s+(\d+)\s+(\d+)"
        buffers_cache_match = re.search(buffers_cache_pattern, raw_output)
        
        # Parse total memory từ Mem line
        # Format: "Mem: 255780 214016 41764 67512 6108 116692"
        mem_pattern = r"Mem:\s+(\d+)"
        mem_match = re.search(mem_pattern, raw_output)

        if buffers_cache_match and mem_match:
            total_kb = int(mem_match.group(1))
            used_without_buffers_cache = int(buffers_cache_match.group(1))
            
            # Tính toán usage percentage theo kiểu Linux free (trừ buffers/cache)
            ram_used_percent = round((used_without_buffers_cache / total_kb) * 100, 2) if total_kb > 0 else 0
            
            metrics.append(
                f"switch_sys,agent_host={host},metric_type=memory mem_used_percent={ram_used_percent} {timestamp}"
            )
            print(f"Memory metrics parsed successfully for {host}: {ram_used_percent}% (Linux-style, excluding buffers/cache)", file=sys.stderr)
        else:
            print(f"Warning: Memory data not found in 'show memory statistics' output for {host}", file=sys.stderr)
    else:
        print(f"No output received from memory command for {host}", file=sys.stderr)

    return metrics

def get_cpu_stats(ssh_client, host):
    """Thu thập CPU metrics từ 'show cpu'."""
    raw_output = ssh_client.send_command("show cpu utilization")
    metrics = []
    timestamp = int(time.time() * 1e9)

    if raw_output:
        print(f"CPU command output for {host}:\n{raw_output}", file=sys.stderr)
        
        # Regex để parse CPU usage - tìm 5 second average
        # Format: "five seconds: 100%; one minute: 31%; five minutes: 34%"
        cpu_pattern = r"five minutes:\s*(\d+)%"
        cpu_match = re.search(cpu_pattern, raw_output)

        if cpu_match:
            cpu_used_percent = int(cpu_match.group(1))
            
            metrics.append(
                f"switch_sys,agent_host={host},metric_type=cpu cpu_used_percent={cpu_used_percent} {timestamp}"
            )
            print(f"CPU metrics parsed successfully for {host}: {cpu_used_percent}%", file=sys.stderr)
        else:
            print(f"Warning: CPU data not found in 'show cpu utilization' output for {host}", file=sys.stderr)
    else:
        print(f"No output received from CPU command for {host}", file=sys.stderr)

    return metrics

def collect_metrics_from_device(device_config):
    """Collect metrics from a single device."""
    host = device_config['hostname']
    print(f"Starting metrics collection for {host}", file=sys.stderr)
    
    ssh_client = CiscoSSHClient(
        hostname=device_config['hostname'],
        port=device_config['port'],
        username=device_config['username'],
        password=device_config['password'],
        enable_password=device_config['enable_password']
    )

    device_metrics = []
    
    if ssh_client.connect_and_login():
        print(f"Successfully connected to {host}, collecting metrics...", file=sys.stderr)
        
        # Thu thập CPU metrics
        cpu_metrics = get_cpu_stats(ssh_client, host)
        if cpu_metrics:
            device_metrics.extend(cpu_metrics)
        else:
            print(f"No CPU metrics collected from {host}.", file=sys.stderr)
        
        # Thu thập Memory metrics
        memory_metrics = get_memory_stats(ssh_client, host)
        if memory_metrics:
            device_metrics.extend(memory_metrics)
        else:
            print(f"No Memory metrics collected from {host}.", file=sys.stderr)

        ssh_client.close()
        print(f"Completed metrics collection for {host}", file=sys.stderr)
    else:
        print(f"Failed to establish SSH connection or login for {host}. Check credentials and switch configuration.", file=sys.stderr)
    
    return device_metrics

# --- Main execution ---
if __name__ == "__main__":
    # Load all device configurations
    devices = load_device_configs()
    
    if not devices:
        print("No valid device configurations found in .env file.", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(devices)} device(s) to monitor", file=sys.stderr)
    
    all_metrics = []
    
    # Sequential processing for better debugging
    for device_config in devices:
        device_metrics = collect_metrics_from_device(device_config)
        all_metrics.extend(device_metrics)
    
    # Output all collected metrics
    for metric_line in all_metrics:
        print(metric_line)
    
    print(f"Total metrics collected: {len(all_metrics)}", file=sys.stderr) 