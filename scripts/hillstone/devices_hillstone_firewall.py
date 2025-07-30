import paramiko
import time
import os
import re
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from dotenv import load_dotenv

# --- Thông tin kết nối và xác thực ---
# Load môi trường từ file .env cùng thư mục với file này
script_dir = os.path.dirname(os.path.abspath(__file__))
env_path = os.path.join(script_dir, '.env')
load_dotenv(env_path)

# Load cấu hình thiết bị từ biến môi trường

def load_device_configs():
    """Load tất cả cấu hình thiết bị Hillstone từ biến môi trường"""
    devices = []
    device_num = 1
    
    while True:
        host_key = f'HILLSTONE_HOST_{device_num}'
        host = os.getenv(host_key)
        
        if not host:
            break
            
        device_config = {
            'hostname': host,
            'port': int(os.getenv(f'HILLSTONE_PORT_{device_num}', 22)),
            'username': os.getenv(f'HILLSTONE_USERNAME_{device_num}'),
            'password': os.getenv(f'HILLSTONE_PASSWORD_{device_num}')
        }
        
        # Validate required fields
        if device_config['username'] and device_config['password']:
            devices.append(device_config)
            print(f"Loaded device config for {host}", file=sys.stderr)
        else:
            print(f"Warning: Incomplete config for device {device_num}, skipping", file=sys.stderr)
            
        device_num += 1
    
    return devices

# --- Lớp xử lý kết nối và tương tác SSH ---
class HillstoneSSHClient:
    def __init__(self, hostname, port, username, password):
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.client = None
        self.channel = None

    def _read_channel_output(self, timeout=5):
        output = ""
        start_time = time.time()
        while time.time() - start_time < timeout:
            if self.channel and self.channel.recv_ready():
                output += self.channel.recv(4096).decode('utf-8', errors='ignore')
            else:
                time.sleep(0.1)
        return output

    def connect(self):
        try:
            self.client = paramiko.SSHClient()
            self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.client.connect(
                hostname=self.hostname,
                port=self.port,
                username=self.username,
                password=self.password,
                timeout=15
            )
            print(f"SSH connected to {self.hostname}.", file=sys.stderr)
            return True
        except Exception as e:
            print(f"Error: SSH connection failed to {self.hostname}: {e}", file=sys.stderr)
            self.client = None
            return False

    def interactive_login(self):
        if not self.client:
            return False
        try:
            self.channel = self.client.invoke_shell()
            time.sleep(1)
            output = self._read_channel_output()

            if "Username:" in output or "login:" in output:
                self.channel.send(self.username + "\n")
                time.sleep(1)
                output = self._read_channel_output()

            if "Password:" in output:
                self.channel.send(self.password + "\n")
                time.sleep(1)
                output = self._read_channel_output()

            # Hillstone: chỉ cần có dòng kết thúc bằng # hoặc chứa [DBG]# là login thành công
            lines = output.strip().splitlines()
            has_prompt = any(line.strip().endswith('#') or '[DBG]#' in line for line in lines)
            if has_prompt:
                return True
            else:
                print(f"Error: Could not login to {self.hostname}. Final output: {output}", file=sys.stderr)
                return False
        except Exception as e:
            print(f"Error: Interactive login failed on {self.hostname}: {e}", file=sys.stderr)
            self.channel = None
            return False

    def send_command(self, command, delay=2):
        if not self.channel:
            print(f"Error: No channel available to execute command '{command}'.", file=sys.stderr)
            return None
        try:
            self.channel.send(command + "\n")
            time.sleep(delay)
            output = ""
            start_time = time.time()
            while time.time() - start_time < 10:
                if self.channel.recv_ready():
                    output += self.channel.recv(4096).decode('utf-8', errors='ignore')
                else:
                    time.sleep(0.1)
                if output.strip().endswith('#'):
                    break
            output_lines = output.strip().splitlines()
            clean_output = []
            for line in output_lines:
                if not line.strip().startswith(command.strip()) and \
                   not line.strip().endswith('#') and \
                   not line.strip() == '':
                    clean_output.append(line.strip())
            return "\n".join(clean_output).strip()
        except Exception as e:
            print(f"Error: Failed to execute command '{command}' on {self.hostname}: {e}", file=sys.stderr)
            return None

    def close(self):
        if self.client:
            self.client.close()

# --- Hàm thu thập metrics và format cho Telegraf ---
def get_cpu_stats(ssh_client, host):
    """Thu thập CPU metrics từ lệnh 'show cpu' trên Hillstone."""
    output = ssh_client.send_command("show cpu")
    metrics = []
    timestamp = int(time.time() * 1e9)
    if output:
        # Ví dụ output:
        # Average cpu utilization : 0.9%
        # Current cpu utilization : 2.0%
        # Last 1 minute : 2.1%
        # Last 5 minutes : 1.7%
        # Last 15 minutes : 1.8%
        avg_pattern = r"Average cpu utilization\s*:\s*([\d.]+)%"
        cur_pattern = r"Current cpu utilization\s*:\s*([\d.]+)%"
        min1_pattern = r"Last 1 minute\s*:\s*([\d.]+)%"
        min5_pattern = r"Last 5 minutes\s*:\s*([\d.]+)%"
        min15_pattern = r"Last 15 minutes\s*:\s*([\d.]+)%"
        avg = re.search(avg_pattern, output)
        cur = re.search(cur_pattern, output)
        min1 = re.search(min1_pattern, output)
        min5 = re.search(min5_pattern, output)
        min15 = re.search(min15_pattern, output)
        if avg and cur and min1 and min5 and min15:
            metrics.append(
                f"hillstone_cpu,agent_host={host} avg={float(avg.group(1))},cur={float(cur.group(1))},min1={float(min1.group(1))},min5={float(min5.group(1))},min15={float(min15.group(1))} {timestamp}"
            )
        else:
            print(f"Warning: 'show cpu' output not parsed as expected for {host}. Raw output:\n{output}", file=sys.stderr)
    return metrics

def get_memory_stats(ssh_client, host):
    """Thu thập Memory metrics từ 'show memory' trên Hillstone."""
    output = ssh_client.send_command("show memory")
    metrics = []
    timestamp = int(time.time() * 1e9)
    if output:
        # Ví dụ output:
        # The percentage of memory utilization: 25%
        #    total(KB)    used(KB)   free(KB)
        #    2097152      528078     1569074   
        percent_pattern = r"The percentage of memory utilization:\s*([\d.]+)%"
        mem_pattern = r"(\d+)\s+(\d+)\s+(\d+)"
        percent = re.search(percent_pattern, output)
        mem = re.search(mem_pattern, output)
        if percent and mem:
            total = int(mem.group(1))
            used = int(mem.group(2))
            free = int(mem.group(3))
            usage = float(percent.group(1))
            metrics.append(
                f"hillstone_memory,agent_host={host} total={total}i,used={used}i,free={free}i,usage={usage} {timestamp}"
            )
        else:
            print(f"Warning: 'show memory' output not parsed as expected for {host}. Raw output:\n{output}", file=sys.stderr)
    return metrics

def collect_metrics_from_device(device_config):
    host = device_config['hostname']
    print(f"Starting metrics collection for {host}", file=sys.stderr)
    ssh_client = HillstoneSSHClient(
        hostname=device_config['hostname'],
        port=device_config['port'],
        username=device_config['username'],
        password=device_config['password']
    )
    device_metrics = []
    if ssh_client.connect() and ssh_client.interactive_login():
        print(f"Successfully connected to {host}, collecting metrics...", file=sys.stderr)
        cpu_metrics = get_cpu_stats(ssh_client, host)
        if cpu_metrics:
            device_metrics.extend(cpu_metrics)
        else:
            print(f"No CPU metrics collected from {host}.", file=sys.stderr)
        memory_metrics = get_memory_stats(ssh_client, host)
        if memory_metrics:
            device_metrics.extend(memory_metrics)
        else:
            print(f"No Memory metrics collected from {host}.", file=sys.stderr)
        ssh_client.close()
        print(f"Completed metrics collection for {host}", file=sys.stderr)
    else:
        print(f"Failed to establish SSH connection or login for {host}. Check credentials and device configuration.", file=sys.stderr)
    return device_metrics

# --- Main execution ---
if __name__ == "__main__":
    devices = load_device_configs()
    if not devices:
        print("No valid device configurations found in .env file.", file=sys.stderr)
        sys.exit(1)
    print(f"Found {len(devices)} device(s) to monitor", file=sys.stderr)
    all_metrics = []
    LIMIT_WORKERS = 3
    max_workers = min(len(devices), LIMIT_WORKERS)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_device = {executor.submit(collect_metrics_from_device, device): device for device in devices}
        for future in as_completed(future_to_device):
            device = future_to_device[future]
            try:
                device_metrics = future.result()
                all_metrics.extend(device_metrics)
            except Exception as exc:
                print(f"Device {device['hostname']} generated an exception: {exc}", file=sys.stderr)
    for metric_line in all_metrics:
        print(metric_line)