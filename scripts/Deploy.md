# Hướng Dẫn Triển Khai Hệ Thống Giám Sát

## Tổng Quan

Hệ thống giám sát này giúp bạn theo dõi hiệu suất và trạng thái của các thiết bị mạng một cách tự động. Hệ thống bao gồm:

- **Telegraf**: Thu thập dữ liệu từ các thiết bị
- **InfluxDB**: Lưu trữ dữ liệu
- **Grafana**: Hiển thị biểu đồ và báo cáo (tùy chọn)

## Các Bước Triển Khai

### Bước 1: Chuẩn Bị

1. **Máy chủ**: Cần một máy chủ Linux (Ubuntu/CentOS) với quyền admin
2. **Kết nối mạng**: Máy chủ phải có thể kết nối đến các thiết bị cần giám sát
3. **Thông tin thiết bị**: Chuẩn bị thông tin đăng nhập của các thiết bị Cisco, Hillstone

### Bước 2: Tải Và Cài Đặt

1. **Tải mã nguồn**:
   ```bash
   git clone [đường dẫn repository]
   cd collect-metrics
   ```

2. **Chạy script triển khai tự động**:
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh
   ```

   Script này sẽ tự động:
   - Cài đặt Docker (nếu chưa có)
   - Tạo cấu hình Telegraf
   - Khởi động các dịch vụ

### Bước 3: Cấu Hình

1. **Tạo file cấu hình**:
   - Sao chép file `.env.example` thành `.env`
   - Chỉnh sửa thông tin trong file `.env`

2. **Thông tin cần cấu hình**:
   - **InfluxDB**: Tên người dùng, mật khẩu, tên tổ chức
   - **Thiết bị Cisco**: Địa chỉ IP, tên đăng nhập, mật khẩu
   - **Thiết bị Hillstone**: Địa chỉ IP, tên đăng nhập, mật khẩu

### Bước 4: Khởi Động Hệ Thống

1. **Chạy lại script triển khai**:
   ```bash
   ./scripts/deploy.sh
   ```

2. **Kiểm tra trạng thái**:
   ```bash
   docker ps
   ```

## Các Loại Thiết Bị Được Hỗ Trợ

### Thiết Bị Cisco
- **Switch Cisco**: Thu thập thông tin CPU, bộ nhớ, trạng thái cổng
- **Router Cisco**: Thu thập thông tin hiệu suất mạng

### Thiết Bị Hillstone
- **Firewall Hillstone**: Thu thập thông tin bảo mật, hiệu suất

### Máy Chủ Linux
- **CPU**: Sử dụng CPU, nhiệt độ
- **Bộ nhớ**: RAM đã sử dụng, còn trống
- **Ổ cứng**: Dung lượng đã sử dụng, tốc độ đọc/ghi

## Dữ Liệu Thu Thập

### Thông Tin Hệ Thống
- **CPU**: Mức sử dụng CPU theo thời gian thực
- **Bộ nhớ**: Dung lượng RAM đã sử dụng và còn trống
- **Ổ cứng**: Dung lượng đã sử dụng và tốc độ truy cập

### Thông Tin Mạng
- **Trạng thái cổng**: Cổng nào đang hoạt động, cổng nào bị lỗi
- **Băng thông**: Tốc độ truyền dữ liệu qua các cổng
- **Lỗi mạng**: Số lượng gói tin bị lỗi, bị drop

### Thông Tin Bảo Mật (Firewall)
- **Kết nối**: Số lượng kết nối đang hoạt động
- **Tấn công**: Các cuộc tấn công bị chặn
- **Chính sách**: Hiệu quả của các chính sách bảo mật

## Truy Cập Dữ Liệu

### Giao Diện Web
- **InfluxDB**: http://localhost:8086
  - Tên đăng nhập: [từ file .env]
  - Mật khẩu: [từ file .env]

### Xem Dữ Liệu
1. Đăng nhập vào InfluxDB
2. Chọn "Data Explorer"
3. Chọn bucket chứa dữ liệu
4. Tạo query để xem dữ liệu mong muốn

## Bảo Trì Hệ Thống

### Kiểm Tra Trạng Thái
```bash
# Kiểm tra các dịch vụ đang chạy
docker ps

# Xem log của Telegraf
docker logs telegraf

# Xem log của InfluxDB
docker logs influxdb
```

### Cập Nhật Cấu Hình
1. Chỉnh sửa file `.env`
2. Chạy lại script triển khai:
   ```bash
   ./scripts/deploy.sh
   ```

### Sao Lưu Dữ Liệu
```bash
# Sao lưu dữ liệu InfluxDB
docker exec influxdb influx backup /backup

# Sao lưu cấu hình
cp .env .env.backup
```

## Xử Lý Sự Cố

### Vấn Đề Thường Gặp

1. **Không kết nối được thiết bị**:
   - Kiểm tra địa chỉ IP và thông tin đăng nhập
   - Kiểm tra kết nối mạng
   - Kiểm tra firewall

2. **Dữ liệu không được thu thập**:
   - Kiểm tra log của Telegraf
   - Kiểm tra cấu hình trong file .env
   - Kiểm tra quyền truy cập thiết bị

3. **Hệ thống chậm**:
   - Kiểm tra tài nguyên máy chủ
   - Giảm tần suất thu thập dữ liệu
   - Tối ưu hóa cấu hình

### Liên Hệ Hỗ Trợ
Nếu gặp vấn đề không thể tự giải quyết, vui lòng:
1. Thu thập log lỗi
2. Chụp ảnh màn hình lỗi
3. Liên hệ đội kỹ thuật

## Lưu Ý Quan Trọng

### Bảo Mật
- Thay đổi mật khẩu mặc định
- Sử dụng mật khẩu mạnh
- Hạn chế quyền truy cập vào máy chủ

### Hiệu Suất
- Hệ thống cần ít nhất 2GB RAM
- Ổ cứng cần ít nhất 10GB dung lượng trống
- Kết nối mạng ổn định

### Sao Lưu
- Sao lưu dữ liệu định kỳ
- Sao lưu cấu hình trước khi thay đổi
- Lưu trữ backup ở vị trí an toàn

## Kết Luận

Hệ thống giám sát này sẽ giúp bạn:
- **Phát hiện sớm** các vấn đề về hiệu suất
- **Theo dõi liên tục** trạng thái thiết bị
- **Báo cáo chi tiết** về hiệu suất hệ thống
- **Tiết kiệm thời gian** trong việc quản lý

Với việc triển khai đúng cách, hệ thống sẽ hoạt động ổn định và cung cấp thông tin hữu ích cho việc quản lý mạng. 