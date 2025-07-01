import paramiko
import time
import os
import re
import sys

# --- Thông tin kết nối và xác thực ---
CISCO_HOST = os.getenv('CISCO_HOST', '172.18.10.2')
CISCO_PORT = int(os.getenv('CISCO_PORT', 22))

CISCO_USERNAME = os.getenv('CISCO_USERNAME', 'hissc_core')
CISCO_PASSWORD = os.getenv('CISCO_PASSWORD', 'Hissc!@#123')

CISCO_ENABLE_PASSWORD = os.getenv('CISCO_ENABLE_PASSWORD', '')

# --- Lớp xử lý kết nối và tương tác SSH ---
class CiscoSSHClient:
    def __init__(self, hostname, port, username, password, enable_password):
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.enable_password = enable_password if enable_password else None
        self.client = None
        self.channel = None

    def _read_channel_output(self, timeout=5):
        """Đọc toàn bộ output từ channel trong một khoảng thời gian."""
        output = ""
        start_time = time.time()
        while time.time() - start_time < timeout:
            if self.channel and self.channel.recv_ready():
                output += self.channel.recv(4096).decode('utf-8', errors='ignore')
            else:
                time.sleep(0.1)
        return output

    def _keyboard_interactive_handler(self, title, instructions, fields):
        """Xử lý các lời nhắc Keyboard-Interactive."""
        responses = []
        for prompt, echo in fields:
            if "username" in prompt.lower():
                responses.append(self.username)
            elif "password" in prompt.lower():
                responses.append(self.password)
            else:
                responses.append("")
        return responses

    def connect(self):
        """Thiết lập kết nối SSH ban đầu, thử các phương thức xác thực."""
        try:
            self.client = paramiko.SSHClient()
            self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            connect_params = {
                'hostname': self.hostname,
                'port': self.port,
                'username': self.username,
                'timeout': 15,
                'disabled_algorithms': {'pubkeys': ['rsa-sha2-256', 'rsa-sha2-512']}
            }

            try:
                connect_params['password'] = self.password
                self.client.connect(**connect_params)
                print(f"SSH connected using password authentication to {self.hostname}.", file=sys.stderr)
                return True
            except paramiko.AuthenticationException:
                print(f"Password authentication failed for {self.hostname}, trying keyboard-interactive...", file=sys.stderr)
                del connect_params['password']
                
                try:
                    self.client.connect(**connect_params, auth_interactive_shell=self._keyboard_interactive_handler)
                    print(f"SSH connected using keyboard-interactive authentication to {self.hostname}.", file=sys.stderr)
                    return True
                except paramiko.AuthenticationException as e:
                    print(f"Error: Keyboard-interactive authentication failed to {self.hostname}: {e}", file=sys.stderr)
                    self.client = None
                    return False
            
        except Exception as e:
            print(f"Error: SSH initial connection failed to {self.hostname}: {e}", file=sys.stderr)
            self.client = None
            return False

    def interactive_login_and_enable(self):
        """Thực hiện login tương tác và vào chế độ enable (nếu cần)."""
        if not self.client:
            return False
        try:
            self.channel = self.client.invoke_shell()
            time.sleep(1) # Chờ prompt ban đầu
            output = self._read_channel_output()

            if "Username:" in output or "login:" in output:
                self.channel.send(self.username + "\n")
                time.sleep(1)
                output = self._read_channel_output()

            if "Password:" in output:
                self.channel.send(self.password + "\n")
                time.sleep(1)
                output = self._read_channel_output()

            if not output.strip().endswith('#'):
                self.channel.send("enable\n")
                time.sleep(1)
                output = self._read_channel_output()

                if "Password:" in output and self.enable_password:
                    self.channel.send(self.enable_password + "\n")
                    time.sleep(1)
                    output = self._read_channel_output()
                elif "Password:" in output and not self.enable_password:
                    print(f"Warning: Switch requires enable password but none provided for {self.hostname}.", file=sys.stderr)
                    return False
            
            if output.strip().endswith('#'):
                return True
            else:
                print(f"Error: Could not enter privileged EXEC mode on {self.hostname}. Final output: {output}", file=sys.stderr)
                return False

        except Exception as e:
            print(f"Error: Interactive login/enable failed on {self.hostname}: {e}", file=sys.stderr)
            self.channel = None
            return False

    def send_command(self, command, delay=2):
        """Gửi lệnh và thu nhận kết quả thông qua kênh tương tác."""
        if not self.channel:
            print(f"Error: No channel available to execute command '{command}'.", file=sys.stderr)
            return None
        try:
            self.channel.send(command + "\n")
            time.sleep(delay)
            output = ""
            start_time = time.time()
            while time.time() - start_time < 15:
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
        """Đóng kết nối SSH."""
        if self.client:
            self.client.close()

# --- Hàm thu thập metrics và format cho Telegraf ---

def get_cpu_stats(ssh_client):
    """Thu thập CPU metrics từ lệnh 'show cpu'."""
    output = ssh_client.send_command("show cpu")
    metrics = []
    timestamp = int(time.time() * 1e9)

    if output:
        cpu_pattern = r"CPU utilization for five seconds: (\d+)%; one minute: (\d+)%; five minutes: (\d+)%;"
        cpu_match = re.search(cpu_pattern, output)
        
        if cpu_match:
            five_sec_cpu = int(cpu_match.group(1))
            one_min_cpu = int(cpu_match.group(2))
            five_min_cpu = int(cpu_match.group(3))
            
            metrics.append(
                f"cisco_cpu,host={CISCO_HOST} "
                f"five_sec={five_sec_cpu}i,one_min={one_min_cpu}i,five_min={five_min_cpu}i {timestamp}"
            )
        else:
            print(f"Warning: 'show cpu' output not parsed as expected. Raw output:\n{output}", file=sys.stderr)
    return metrics

def get_memory_stats(ssh_client):
    """Thu thập Memory (RAM) metrics từ 'show tech-support memory'."""
    raw_output = ssh_client.send_command("show tech-support memory", delay=5)
    metrics = []
    timestamp = int(time.time() * 1e9)

    if raw_output:
        # Regex cho Dynamic RAM usage, làm cho nó linh hoạt hơn với khoảng trắng và dòng mới
        # Sử dụng (?:.|\n)*? để khớp bất kỳ ký tự nào (kể cả xuống dòng) một cách không tham lam
        # dynamic_ram_pattern = r"Dynamic \(OS managed\) RAM usage:(?:.|\n)*?Requested = (\d+), Free = (\d+), Used = (\d+), Usage = (\d+)%"
        # dynamic_match = re.search(dynamic_ram_pattern, raw_output) # re.DOTALL không còn cần với (?:.|\n)*?

        # if dynamic_match:
        #     requested_dyn = int(dynamic_match.group(1))
        #     free_dyn = int(dynamic_match.group(2))
        #     used_dyn = int(dynamic_match.group(3))
        #     usage_dyn = int(dynamic_match.group(4))
        #     metrics.append(
        #         f"cisco_memory_dynamic,host={CISCO_HOST} "
        #         f"requested={requested_dyn}i,free={free_dyn}i,used={used_dyn}i,usage={usage_dyn}i {timestamp}"
        #     )
        # else:
        #     print("Warning: Dynamic RAM data not found in 'show tech-support memory' output.", file=sys.stderr)

        # Regex cho Local RAM usage, tương tự làm linh hoạt hơn
        local_ram_pattern = r"Local \(ROS managed\) RAM usage:(?:.|\n)*?Total = (\d+), Free = (\d+), Used = (\d+), Usage = (\d+)%"
        local_match = re.search(local_ram_pattern, raw_output)

        if local_match:
            total_local = int(local_match.group(1))
            free_local = int(local_match.group(2))
            used_local = int(local_match.group(3))
            usage_local = int(local_match.group(4))
            metrics.append(
                f"memory,agent_host={CISCO_HOST} "
                f"total={total_local}i,free={free_local}i,used={used_local}i,usage={usage_local}i {timestamp}"
            )
        else:
            print("Warning: Local RAM data not found in 'show tech-support memory' output.", file=sys.stderr)

    return metrics

def get_interface_stats(ssh_client):
    """
    Thu thập Interface stats.
    Regex bên dưới là ví dụ, cần kiểm tra output thực tế của bạn.
    """
    output = ssh_client.send_command("show interface status")
    metrics = []
    timestamp = int(time.time() * 1e9)

    if output:
        interface_pattern = r"(\S+)\s+(connected|notconnect|disabled)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)"
        
        for line in output.splitlines():
            match = re.search(interface_pattern, line.strip())
            if match:
                interface_name = match.group(1)
                status_str = match.group(2)
                protocol_str = match.group(3) 
                
                status = 1 if status_str == 'connected' else 0
                
                protocol = 1 if 'up' in protocol_str.lower() else 0

                vlan = match.group(6) 

                metrics.append(
                    f"cisco_interface,host={CISCO_HOST},interface={interface_name} "
                    f"status={status}i,protocol={protocol}i,vlan=\"{vlan}\" {timestamp}"
                )
    return metrics

# --- Main execution ---
if __name__ == "__main__":
    ssh_client = CiscoSSHClient(
        hostname=CISCO_HOST,
        port=CISCO_PORT,
        username=CISCO_USERNAME,
        password=CISCO_PASSWORD,
        enable_password=CISCO_ENABLE_PASSWORD
    )

    if ssh_client.connect() and ssh_client.interactive_login_and_enable():
        all_metrics = []
        
        # cpu_metrics = get_cpu_stats(ssh_client)
        # if cpu_metrics:
        #     all_metrics.extend(cpu_metrics)
        # else:
        #     print("No CPU metrics collected.", file=sys.stderr)

        memory_metrics = get_memory_stats(ssh_client)
        if memory_metrics:
            all_metrics.extend(memory_metrics)
        else:
            print("No Memory metrics collected.", file=sys.stderr)

        # interface_metrics = get_interface_stats(ssh_client)
        # if interface_metrics:
        #     all_metrics.extend(interface_metrics)
        # else:
        #     print("No Interface metrics collected.", file=sys.stderr)


        for line in all_metrics:
            print(line)
        
        ssh_client.close()
    else:
        print("Failed to establish SSH connection or login/enable. Check credentials and switch configuration.", file=sys.stderr)