### 1. Hiểu Vấn Đề Khi Chạy `inputs.exec` Từ Container

Khi Telegraf chạy trong một container, nó bị cô lập khỏi hệ thống tệp và các công cụ trên máy chủ Ubuntu của bạn. Do đó:

* **Script cần ở đâu?** Script bạn dùng để thu thập metric từ Cisco switch (ví dụ: một script Python sử dụng Netmiko, hay một lệnh SNMP trực tiếp) cần phải tồn tại và chạy được **bên trong container Telegraf**, HOẶC container Telegraf cần có quyền truy cập vào script đó trên máy chủ.
* **Các công cụ cần thiết:** Nếu script của bạn yêu cầu Python, Netmiko, hay các công cụ SNMP (như `snmpwalk`), thì những công cụ này cũng phải được cài đặt **bên trong container Telegraf** hoặc được truy cập thông qua các mount volume.
* **Truy cập mạng:** Container Telegraf cần có khả năng truy cập mạng để kết nối tới các Cisco switch của bạn.

Giải pháp tốt nhất là **gắn (mount) script từ máy chủ vào container** và đảm bảo container có các công cụ cần thiết.

---

### 2. Chuẩn Bị Script Thu Thập Metric Trên Máy Chủ Ubuntu

Đầu tiên, hãy đảm bảo rằng script của bạn hoạt động độc lập trên máy chủ Ubuntu.
Giả sử bạn có một script Python tên là `get_cisco_metrics.py` nằm ở `/opt/scripts/get_cisco_metrics.py`. Script này sẽ kết nối tới Cisco switch và xuất dữ liệu ở định dạng mà Telegraf có thể hiểu (ví dụ: InfluxDB line protocol hoặc JSON).

**Ví dụ một phần của `get_cisco_metrics.py` (cần có Netmiko đã cài đặt):**

```python
# /opt/scripts/get_cisco_metrics.py
import netmiko
import json
import sys
import os

# Thông tin switch có thể đọc từ biến môi trường hoặc file cấu hình
# Đối với ví dụ đơn giản này, chúng ta hardcode, nhưng trong thực tế nên linh hoạt hơn
CISCO_HOST = os.getenv('CISCO_HOST', 'your_cisco_switch_ip')
CISCO_USER = os.getenv('CISCO_USER', 'your_username')
CISCO_PASS = os.getenv('CISCO_PASS', 'your_password')

def get_interface_stats():
    device = {
        "device_type": "cisco_ios",
        "host": CISCO_HOST,
        "username": CISCO_USER,
        "password": CISCO_PASS,
    }
    try:
        with netmiko.ConnectHandler(**device) as net_connect:
            # Lấy trạng thái giao diện
            output = net_connect.send_command("show interface status", use_textfsm=True)
            metrics = []
            for intf in output:
                interface_name = intf.get('port')
                status = 1 if intf.get('status') == 'connected' else 0
                protocol = 1 if intf.get('protocol') == 'up' else 0
                vlan = intf.get('vlan')

                # Xuất dưới dạng InfluxDB line protocol
                # Định dạng: measurement,tag_key=tag_value field_key=field_value timestamp
                # VD: cisco_interface,host=192.168.1.1,interface=GigabitEthernet1/0/1 status=1i,protocol=1i
                metrics.append(
                    f"cisco_interface,host={CISCO_HOST},interface={interface_name} "
                    f"status={status}i,protocol={protocol}i,vlan=\"{vlan}\""
                )
            return metrics
    except Exception as e:
        print(f"Error connecting to Cisco switch or getting data: {e}", file=sys.stderr)
        return []

if __name__ == "__main__":
    data = get_interface_stats()
    for line in data:
        print(line)

```
**Lưu ý:**
* Đảm bảo script này có quyền thực thi (`chmod +x /opt/scripts/get_cisco_metrics.py`).
* Hãy đảm bảo **Netmiko đã được cài đặt** trên môi trường mà script này sẽ chạy (tức là bên trong container Telegraf). Bạn có thể cần tạo một Dockerfile tùy chỉnh cho Telegraf để cài đặt Netmiko.

---

### 3. Cập Nhật Cấu Hình Telegraf Trong Container

Vì bạn đang dùng Telegraf trong container, bạn sẽ cần thực hiện các thay đổi sau:

#### A. Sửa Đổi Tệp Cấu Hình Telegraf Trên Máy Chủ

Tìm tệp cấu hình Telegraf mà bạn gắn vào container (ví dụ: `/etc/telegraf/telegraf.conf` trên máy chủ). Mở tệp đó:

```bash
sudo nano /etc/telegraf/telegraf.conf # Hoặc đường dẫn mà bạn đang mount
```

Thêm cấu hình `inputs.exec` vào cuối tệp hoặc trong phần `[[inputs]]` hiện có:

```ini
# ---
# inputs.exec for Cisco Switch Metrics
# ---
[[inputs.exec]]
  ## Các lệnh để thực thi.
  ## Để đảm bảo rằng các trường có tên riêng biệt, mỗi lệnh
  ## cần có tên riêng biệt hoặc một bí danh được chỉ định.
  # commands = ["/usr/bin/my_script.sh", "my_script_2.sh --json"]

  # Đường dẫn tới script get_cisco_metrics.py bên TRONG CONTAINER
  # (Giả sử bạn mount thư mục /opt/scripts thành /scripts bên trong container)
  commands = ["/usr/bin/python3 /scripts/get_cisco_metrics.py"]

  ## Xác định định dạng dữ liệu đầu ra của lệnh.
  ## Có thể là: influx, json, prometheus, graphite, value, gmetric, collectd, dropwizard, csv
  data_format = "influx" # Vì script của chúng ta xuất InfluxDB line protocol

  ## Khoảng thời gian thu thập (mặc định là 10 giây).
  interval = "60s" # Ví dụ: Thu thập mỗi 60 giây

  ## Tên dịch vụ để sử dụng cho số liệu.
  # name_override = "cisco_metrics"

  ## Thêm các thẻ vào tất cả các số liệu được tạo bởi plugin này.
  [inputs.exec.tags]
    source_system = "cisco_switch"
```

**Lưu ý quan trọng:**

* **`commands = ["/usr/bin/python3 /scripts/get_cisco_metrics.py"]`**: Đường dẫn này là đường dẫn **bên trong container**. Chúng ta sẽ mount thư mục chứa script trên máy chủ vào `/scripts` bên trong container.
* **`data_format = "influx"`**: Đây là quan trọng để Telegraf hiểu dữ liệu từ script của bạn.

Lưu tệp cấu hình này.

#### B. Sửa Đổi Lệnh `docker run` Hoặc `docker-compose.yml`

Để container Telegraf có thể truy cập script của bạn và có các công cụ cần thiết (như Python và Netmiko), bạn có hai lựa chọn chính:

**Lựa chọn 1: Gắn Script và Sử Dụng Telegraf Image Cơ Bản (Phức tạp hơn)**

Đây là cách nếu bạn muốn giữ image Telegraf mặc định, nhưng nó yêu cầu script của bạn tự đóng gói tất cả phụ thuộc hoặc Telegraf container đã có sẵn các thứ đó. Thường thì Telegraf image cơ bản không có Python hay Netmiko.

**Lựa chọn 2: Xây Dựng Một Docker Image Telegraf Tùy Chỉnh (Được khuyến nghị)**

Đây là cách tốt nhất vì bạn có thể cài đặt tất cả các phụ thuộc (Python, Netmiko) trực tiếp vào image Telegraf, đảm bảo môi trường nhất quán.

**Bước 1: Tạo `Dockerfile` tùy chỉnh**

Tạo một tệp `Dockerfile` cùng thư mục với `telegraf.conf` (hoặc một thư mục riêng biệt) với nội dung sau:

```dockerfile
# Dockerfile
FROM telegraf:latest # Bắt đầu từ image Telegraf chính thức mới nhất

# Cài đặt Python3 và pip
RUN apk add --no-cache python3 py3-pip

# Cài đặt Netmiko
RUN pip3 install netmiko

# Copy tệp cấu hình Telegraf vào vị trí mặc định của nó
# Bạn có thể bỏ qua dòng này nếu bạn vẫn muốn mount telegraf.conf từ bên ngoài
# COPY telegraf.conf /etc/telegraf/telegraf.conf

# Tạo thư mục cho script của bạn
RUN mkdir -p /scripts

# Không cần COPY script vào đây nếu bạn muốn mount nó từ bên ngoài,
# điều này linh hoạt hơn khi bạn cập nhật script.
# Nếu bạn muốn đóng gói script vào image, hãy thêm:
# COPY get_cisco_metrics.py /scripts/get_cisco_metrics.py
# RUN chmod +x /scripts/get_cisco_metrics.py
```

**Bước 2: Xây dựng image Docker**

Trong thư mục chứa `Dockerfile` của bạn, chạy lệnh:

```bash
docker build -t my-telegraf-cisco:latest .
```

**Bước 3: Chạy container với image tùy chỉnh và gắn script**

Bây giờ, khi chạy container, bạn sẽ sử dụng image `my-telegraf-cisco` vừa tạo và gắn script từ máy chủ vào.

```bash
docker run -d \
  --name telegraf \
  --network host \ # Hoặc sử dụng network bridge và expose port nếu cần InfluxDB bên ngoài
  -v /etc/telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro \
  -v /opt/scripts:/scripts:ro \ # Gắn thư mục script từ máy chủ vào /scripts trong container
  -e CISCO_HOST="192.168.1.10" \ # Truyền biến môi trường cho script
  -e CISCO_USER="admin" \
  -e CISCO_PASS="your_secret_password" \
  my-telegraf-cisco:latest
```

**Giải thích các tùy chọn Docker quan trọng:**

* **`--network host`**: Cho phép container truy cập trực tiếp vào network của host. Điều này đơn giản hóa việc kết nối đến InfluxDB (nếu nó chạy trên cùng máy chủ) và các Cisco switch. Nếu không, bạn sẽ phải cấu hình network bridge và ánh xạ port.
* **`-v /etc/telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro`**: Gắn tệp cấu hình Telegraf từ máy chủ vào container.
* **`-v /opt/scripts:/scripts:ro`**: **Đây là key!** Nó gắn thư mục `/opt/scripts` trên máy chủ của bạn (nơi chứa `get_cisco_metrics.py`) vào thư mục `/scripts` bên trong container. Đảm bảo script có quyền thực thi.
* **`-e CISCO_HOST="..."`**: Truyền các biến môi trường vào container. Đây là cách an toàn hơn để cung cấp thông tin đăng nhập/kết nối cho script của bạn thay vì nhúng trực tiếp vào script.

---

### 4. Khởi Động Lại và Kiểm Tra

1.  **Dừng và xóa container Telegraf cũ:**
    ```bash
    docker stop telegraf
    docker rm telegraf
    ```

2.  **Chạy container mới** với lệnh `docker run` đã được điều chỉnh ở trên.

3.  **Kiểm tra nhật ký của container Telegraf:**
    ```bash
    docker logs telegraf
    ```
    Hãy tìm bất kỳ lỗi nào liên quan đến việc thực thi script hoặc gửi dữ liệu.

4.  **Kiểm tra InfluxDB:** Truy vấn InfluxDB để xem liệu dữ liệu `cisco_interface` có đang được thu thập hay không.

    ```sql
    SELECT * FROM cisco_interface
    ```

---

Bằng cách sử dụng một Dockerfile tùy chỉnh để cài đặt các phụ thuộc và gắn script từ máy chủ, bạn sẽ có một giải pháp mạnh mẽ và dễ quản lý để thu thập metrics từ Cisco switch của mình bằng Telegraf container.