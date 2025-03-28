# Dockerfile
ARG TELEGRAF_VERSION=1.25.0
FROM telegraf:${TELEGRAF_VERSION}

# Cài đặt các gói bổ sung cho cả Debian-based (Ubuntu) và RHEL-based (CentOS)
RUN if grep -q 'ID=debian\|ID=ubuntu\|ID_LIKE=debian' /etc/os-release 2>/dev/null; then \
        # Debian/Ubuntu installation
        echo "deb http://deb.debian.org/debian bullseye non-free" >> /etc/apt/sources.list && \
        apt-get update && \
        apt-get install -y snmp snmp-mibs-downloader && \
        download-mibs && \
        rm -rf /var/lib/apt/lists/* && \
        sed -i 's/mibs :/# mibs :/g' /etc/snmp/snmp.conf && \
        echo "mibs +ALL" >> /etc/snmp/snmp.conf; \
    elif grep -q 'ID=centos\|ID=rhel\|ID=fedora\|ID=amzn' /etc/os-release 2>/dev/null; then \
        # CentOS/RHEL/Fedora installation
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
