# Dockerfile
ARG TELEGRAF_IMAGE=telegraf:1.27.0
FROM ${TELEGRAF_IMAGE}

# Cài đặt các gói bổ sung cho Debian-based (Ubuntu)
RUN if grep -q 'ID=debian\|ID=ubuntu\|ID_LIKE=debian' /etc/os-release 2>/dev/null; then \
        # Debian/Ubuntu installation
        echo "deb http://deb.debian.org/debian bullseye non-free" >> /etc/apt/sources.list && \
        apt-get update && \
        # Cài đặt SNMP cho plugin SNMP của Telegraf
        apt-get install -y snmp snmp-mibs-downloader && \
        download-mibs && \
        rm -rf /var/lib/apt/lists/* && \
        sed -i 's/mibs :/# mibs :/g' /etc/snmp/snmp.conf && \
        echo "mibs +ALL" >> /etc/snmp/snmp.conf && \
        \
        # --- BẮT ĐẦU CÀI ĐẶT PYTHON VÀ PARAMIKO CHO DEBIAN --- \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            python3 \
            python3-pip \
            git \
            openssh-client \
            build-essential \
            libffi-dev \
            libssl-dev \
            libpython3-dev && \
        \
        pip3 install --upgrade pip && \
        pip3 install \
            pexpect \
            paramiko \
            cryptography \
            bcrypt \
            dotenv \
            pynacl && \
        \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    elif grep -q 'ID=centos\|ID=rhel\|ID=fedora\|ID=amzn' /etc/os-release 2>/dev/null; then \
        # CentOS/RHEL/Fedora installation (giữ nguyên nếu bạn cần hỗ trợ đa nền tảng)
        yum -y install epel-release && \
        yum -y install net-snmp net-snmp-utils && \
        mkdir -p /usr/share/snmp/mibs && \
        yum -y install net-snmp-libs && \
        touch /etc/snmp/snmp.conf && \
        echo "mibs +ALL" >> /etc/snmp/snmp.conf && \
        yum clean all; \
    else \
        # Fallback for other distributions
        echo "Unknown distribution, trying to install SNMP packages" && \
        (apt-get update && apt-get install -y snmp || yum -y install net-snmp) && \
        echo "mibs +ALL" >> /etc/snmp/snmp.conf; \
    fi

# Tạo thư mục cho script của bạn (đặt ngoài khối if/elif để đảm bảo luôn được tạo)
RUN mkdir -p /scripts

# Tùy chọn: Nếu bạn có bất kỳ script hoặc file nào muốn đóng gói VÀO image
# (thay vì mount từ bên ngoài), bạn có thể thêm lệnh COPY ở đây.
# COPY ./your_script.py /scripts/your_script.py
# RUN chmod +x /scripts/your_script.py