# Dockerfile
ARG TELEGRAF_VERSION
FROM telegraf:${TELEGRAF_VERSION}

RUN echo "deb http://deb.debian.org/debian bullseye non-free" >> /etc/apt/sources.list

# Cập nhật và cài đặt gói SNMP và MIBs
RUN apt-get update && \
    apt-get install -y snmp snmp-mibs-downloader && \
    download-mibs && \
    rm -rf /var/lib/apt/lists/*

# Bật MIBs trong cấu hình SNMP
RUN echo "mibs +ALL" >> /etc/snmp/snmp.conf
