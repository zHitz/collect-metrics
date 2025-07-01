import paramiko
import time
import logging
import sys
import threading

# Cấu hình logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("device_log.log", mode='a', encoding='utf-8')
    ]
)

class CiscoDeviceInteractive:
    def __init__(self, hostname, port, initial_username, initial_password,
                 second_username, second_password, command):
        self.hostname = hostname
        self.port = port
        self.initial_username = initial_username
        self.initial_password = initial_password  # Nếu không cần, để None hoặc chuỗi rỗng
        self.second_username = second_username
        self.second_password = second_password
        self.command = command
        self.client = None

import paramiko
import socket
import time
import logging

class CiscoDevice:
    def __init__(self, hostname, port, ssh_user, device_user, device_pass):
        self.hostname = hostname
        self.port = port
        self.ssh_user = ssh_user
        self.device_user = device_user
        self.device_pass = device_pass
        self.client = None
        self.channel = None
        self.timeout = 10

    def connect(self):
        logging.info(f"Đang kết nối tới {self.hostname}:{self.port} bằng user {self.ssh_user}")
        try:
            # Kết nối TCP tới thiết bị
            sock = socket.create_connection((self.hostname, self.port), timeout=self.timeout)
            transport = paramiko.Transport(sock)
            transport.connect()  # Không truyền username / password vì không dùng auth chuẩn

            # Mở phiên SSH shell
            self.client = paramiko.SSHClient()
            self.client._transport = transport
            self.channel = transport.open_session()
            self.channel.get_pty()
            self.channel.invoke_shell()
            time.sleep(1)

            # Nhận thông điệp chào mừng + prompt User Name
            output = self.channel.recv(1024).decode('utf-8')
            logging.debug(f"Prompt đầu tiên: {output}")

            if "User Name" in output:
                self.channel.send(self.device_user + "\n")
                time.sleep(1)

            output = self.channel.recv(1024).decode('utf-8')
            logging.debug(f"Sau user: {output}")
            if "Password" in output:
                self.channel.send(self.device_pass + "\n")
                time.sleep(2)

            output = self.channel.recv(4096).decode('utf-8')
            logging.debug(f"Sau password: {output}")
            if ">" in output or "#" in output:
                logging.info("✅ Đăng nhập thiết bị thành công.")
                return self.channel
            else:
                logging.error("❌ Đăng nhập thất bại.")
                return None

        except Exception as e:
            logging.error(f"Lỗi kết nối SSH tới {self.hostname}: {e}")
            return None


    def interactive_login(self):
        """Thực hiện login tương tác sau khi kết nối SSH ban đầu."""
        if not self.client:
            logging.error("Không có kết nối SSH, không thể thực hiện login tương tác.")
            return None
        try:
            channel = self.client.invoke_shell()
            time.sleep(1)  # Chờ đợi prompt ban đầu
            output = channel.recv(1024).decode('utf-8')
            logging.info("Prompt ban đầu: " + output)

            # Kiểm tra và gửi username thứ hai nếu có prompt "Username:"
            if "Username:" in output:
                logging.info("Gửi username thứ hai...")
                channel.send(self.second_username + "\n")
                time.sleep(1)
                output = channel.recv(1024).decode('utf-8')
                logging.info("Sau khi gửi username: " + output)

            # Kiểm tra và gửi password thứ hai nếu có prompt "Password:"
            if "Password:" in output:
                logging.info("Gửi password thứ hai...")
                channel.send(self.second_password + "\n")
                time.sleep(1)
                output = channel.recv(1024).decode('utf-8')
                logging.info("Sau khi gửi password: " + output)

            # Chờ prompt của thiết bị xuất hiện
            time.sleep(1)
            return channel
        except Exception as e:
            logging.error(f"Lỗi trong quá trình login tương tác trên {self.hostname}: {e}")
            return None

    def execute_command(self, channel):
        """Gửi lệnh và thu nhận kết quả thông qua kênh tương tác."""
        if not channel:
            logging.error("Không có kênh để thực thi lệnh.")
            return None
        try:
            logging.info(f"Thực thi lệnh: {self.command}")
            channel.send(self.command + "\n")
            time.sleep(2)  # Điều chỉnh thời gian chờ phản hồi tùy thuộc vào lệnh
            output = ""
            while channel.recv_ready():
                output += channel.recv(1024).decode('utf-8')
            logging.info("Kết quả lệnh: " + output)
            return output
        except Exception as e:
            logging.error(f"Lỗi khi thực thi lệnh trên {self.hostname}: {e}")
            return None

    def close(self):
        """Đóng kết nối SSH."""
        if self.client:
            self.client.close()
            logging.info(f"Đóng kết nối tới {self.hostname}")

def process_device_interactive(device_info):
    """Quy trình kết nối, login tương tác và thực thi lệnh trên một thiết bị."""
    device = CiscoDeviceInteractive(
        hostname=device_info['hostname'],
        port=device_info.get('port', 22),
        initial_username=device_info['initial_username'],
        initial_password=device_info.get('initial_password', ''),
        second_username=device_info['second_username'],
        second_password=device_info['second_password'],
        command=device_info['command']
    )
    device.connect()
    channel = device.interactive_login()
    result = device.execute_command(channel)
    if result:
        logging.info(f"Kết quả từ {device.hostname}:\n{result}")
    device.close()

if __name__ == "__main__":
        # Danh sách thiết bị với thông tin kết nối:
    device = CiscoDevice(
        hostname="172.18.10.2",
        port=22,
        ssh_user="hissc_core",
        device_user="hissc_core",   # hoặc user nội bộ trên thiết bị
        device_pass="Hissc!@#123"
    )
    channel = device.connect()


    threads = []
    for dev in devices:
        thread = threading.Thread(target=process_device_interactive, args=(dev,))
        thread.start()
        threads.append(thread)
    for thread in threads:
        thread.join()

    # Script này có thể được gọi từ telegraf thông qua plugin input.exec để thu thập dữ liệu đầu ra.
