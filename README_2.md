# README 2 — Các thay đổi cho Acer Nitro ANV15-52

Tài liệu này ghi lại các thay đổi hiện có trong source DAMX, cách chúng được triển khai và các vị trí liên quan khi cài đặt. `README.md` gốc được giữ nguyên.

## Đã sửa

### Kết nối GUI với daemon

- Unix socket của GUI được tạo với `ProtocolType.Unspecified` thay cho `ProtocolType.IP`, phù hợp với `AddressFamily.Unix` và tránh lỗi kết nối socket.
- Khi daemon chưa chạy, GUI vẫn mở Dashboard để xem telemetry; các tab điều khiển phần cứng bị vô hiệu hóa. GUI hiện trạng thái offline và có nút thử kết nối lại thay vì chặn bằng hộp thoại phủ toàn màn hình.

### Nhận diện driver và profile nhiệt

- Daemon chờ tối đa 3 giây để Linuwu-Sense tạo nhóm sysfs Nitro/Predator. Daemon không còn liên tục tháo/nạp lại driver khi chưa nhận diện được model.
- `thermal_profile` chỉ được bật khi máy được nhận diện và profile đang hoạt động nằm trong danh sách profile mà firmware công bố.
- Hỗ trợ ANV15-52 cho profile nhiệt được bổ sung trong patch driver riêng. Patch dùng giao diện EC shared-memory cho năm profile ACPI: `low-power`, `quiet`, `balanced`, `balanced-performance` và `performance`.
- Điều khiển quạt thủ công không còn bị chặn riêng cho ANV15-52. Daemon bật tính năng khi driver có file `fan_speed` và ghi duty CPU/GPU theo cặp `CPU,GPU` (`0,0` là Auto, `100,100` là tối đa). Patch EC ở trên chỉ bổ sung profile nhiệt; điều khiển quạt dùng giao diện `fan_speed` đã có của Linuwu-Sense.

### Telemetry GPU

- GPU temperature và usage giờ có thể không có giá trị (`N/A`) thay vì bị hiển thị nhầm thành `0` khi lệnh cảm biến lỗi hoặc trả dữ liệu không hợp lệ.
- Với NVIDIA, GUI đọc `utilization.gpu` bằng `nvidia-smi` với đầu ra không kèm đơn vị và kiểm tra số trong khoảng 0–100. Usage `0%` hợp lệ vẫn được hiển thị là `0%`.
- Thanh nhiệt độ và usage chỉ hiện khi có số liệu; biểu đồ nhiệt GPU chỉ thêm điểm khi nhiệt độ hợp lệ.

### Kết nối và trạng thái giao diện khác

- Profile chỉ xuất hiện khi driver/firmware báo có hỗ trợ. Low Power chỉ hiện khi dùng pin; Quiet, Performance và Turbo chỉ hiện khi cắm sạc; Balanced có thể dùng ở cả hai trạng thái.
- Khi chọn Quiet, GUI đưa quạt về Auto và khóa chọn Manual/Max. Đây là quy tắc chung của giao diện, không phải chặn riêng ANV15-52.

## File được thêm hoặc chỉnh sửa trong repository

- `scripts/patches/linuwu-sense-anv15-52-ec-profile.patch` — patch source Linuwu-Sense để thêm nhận diện ANV15-52 và giao diện profile nhiệt qua EC.
- `ERROR.md` — ghi chú chẩn đoán daemon, driver, quạt và GPU cho máy này.
- `README_2.md` — tài liệu thay đổi và đường dẫn cài đặt này.
- `DAMM-Daemon/DAMX-Daemon.py` — chờ driver, phát hiện profile hợp lệ, bỏ chặn quạt theo model.
- `DivAcerManagerMax/DAMXClient.cs` — sửa loại protocol của Unix socket.
- `DivAcerManagerMax/MainWindow.axaml` và `.axaml.cs` — trạng thái daemon offline/retry và GUI hiển thị dữ liệu GPU không khả dụng.
- `DivAcerManagerMax/Dashboard.axaml` và `.axaml.cs` — parsing và hiển thị GPU temperature/usage.
- `scripts/local-setup.sh` — áp dụng patch vào source Linuwu-Sense trước khi build/cài driver.
- `scripts/remote-setup.sh` — kiểm tra source Linuwu-Sense tải về đã có patch; nếu thiếu, dừng thay vì cài driver không có hỗ trợ profile ANV15-52.
- `scripts/PackageEverything.py` — áp dụng patch vào bản sao driver được đưa vào gói phát hành.

Không có thư viện hoặc ứng dụng ngoài mới được thêm vào GUI/daemon. Patch kernel là phần bổ sung duy nhất cho driver.

## Patch được đặt và áp dụng ở đâu

Patch gốc nằm trong repository tại:

```text
scripts/patches/linuwu-sense-anv15-52-ec-profile.patch
```

Khi đóng gói phát hành, `PackageEverything.py` chép driver vào thư mục package `Linuwu-Sense/` rồi áp dụng patch lên bản sao:

```text
Publish/DAMX-<version>/Linuwu-Sense/src/linuwu_sense.c
```

Khi chạy installer cục bộ, `local-setup.sh` áp dụng patch tại:

```text
Linuwu-Sense/src/linuwu_sense.c
```

Sau đó installer build và gọi `make install` của Linuwu-Sense để cài module cho hệ thống/kernel hiện hành. Đường dẫn cuối của module phụ thuộc phiên bản và cơ chế DKMS/kernel module của Linuwu-Sense; kiểm tra bằng `dkms status` và `modinfo linuwu_sense`. Patch không được chép vào `/opt/damx` như một file chạy độc lập.

`remote-setup.sh` tải source Linuwu-Sense trực tiếp từ upstream và hiện kiểm tra các dấu hiệu patch; nếu upstream chưa có phần hỗ trợ cần thiết thì script dừng cài driver. Bản đóng gói từ `PackageEverything.py` có patch trong thư mục driver đi kèm.

## Vị trí cài DAMX khi chạy installer đóng gói

Nếu cài bằng `setup.sh` của gói phát hành, installer sử dụng các vị trí sau:

| Thành phần | Vị trí hệ thống |
| --- | --- |
| DAMX daemon | `/opt/damx/daemon/DAMX-Daemon` |
| GUI | `/opt/damx/gui/` |
| systemd unit | `/etc/systemd/system/damx-daemon.service` |
| Lệnh mở GUI | `/usr/local/bin/DAMX` |
| Desktop entry | `/usr/share/applications/damx.desktop` |
| Icon | `/usr/share/icons/hicolor/256x256/apps/damx.png` |
| Secure Boot key/certificate, nếu cần | `/var/lib/damx/secureboot/` |

Daemon chạy bằng root dưới systemd. Khi chạy trực tiếp từ source để phát triển, daemon và GUI vẫn nằm trong repository; lệnh cài đặt không tự chép source vào `/opt/damx`:

```sh
sudo python3 DAMM-Daemon/DAMX-Daemon.py
dotnet run --project DivAcerManagerMax/DivAcerManagerMax.csproj
```

## Trạng thái cài đặt và kiểm tra

Các thay đổi được ghi trong source tree. Không có installer hoặc lệnh `sudo make install` nào được chạy trong quá trình cập nhật tài liệu này; vì vậy không nên hiểu các đường dẫn hệ thống ở trên là đã được cài/cập nhật tự động. Sau khi cài driver hoặc cập nhật daemon, cần nạp lại driver/khởi động lại daemon tương ứng để chạy bản mới.

Trên ANV15-52 được kiểm tra, nhóm `nitro_sense` có các file điều khiển pin, backlight, boot sound, fan, LCD và USB; firmware báo đủ năm thermal profile. Nhóm `four_zoned_kb` và thiết bị HID ENEK5130 không được phát hiện, nên điều khiển RGB theo vùng/hiệu ứng không xuất hiện. Model ANV15-52 chưa được liệt kê là model kiểm thử chính thức trong `Compatibility.md`.

Kiểm tra GPU NVIDIA trực tiếp:

```sh
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits --id=0
```

Lệnh trả `0` nghĩa là GPU báo usage 0% tại thời điểm lấy mẫu; nếu `nvidia-smi` báo lỗi driver, GUI sẽ hiển thị `N/A`.
