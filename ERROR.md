# Lỗi kết nối daemon và không thấy điều khiển quạt

Ghi chú để tiếp tục xử lý sau.

## Máy và môi trường

- Acer Nitro V 15 **ANV15-52**, BIOS V1.53.
- Fedora 44, kernel `7.2.13-200.fc44.x86_64` (theo ghi chú của người dùng).
- Module đang dùng là `linuwu_sense`; tránh để `asense_rgb` cùng nạp và điều khiển máy.

## Đã xảy ra

1. Chạy GUI bằng `dotnet run` báo `Failed to connect to daemon: Cannot assign requested address`.
2. `sudo systemctl status damx-daemon.service` trả `Unit damx-daemon.service could not be found` và `/var/run/DAMX.sock` chưa tồn tại. Nguyên nhân: DAMX daemon chưa được cài/chạy thành systemd service.
3. GUI sau đó hiện tab profile, nhưng người dùng nói bấm nút không có tác dụng.

## Cách chạy GUI từ mã nguồn hiện tại

Mở terminal thứ nhất và giữ daemon chạy:

```sh
cd ~/Program_File/Div-Acer-Manager-Max
sudo python3 DAMM-Daemon/DAMX-Daemon.py
```

Mở terminal thứ hai để chạy GUI:

```sh
cd ~/Program_File/Div-Acer-Manager-Max
dotnet run --project DivAcerManagerMax/DivAcerManagerMax.csproj
```

Đường dẫn project kết thúc bằng `.csproj`.

Đây là cách chạy daemon trực tiếp, **không cài service**. Nếu đóng terminal daemon thì socket mất và GUI mất kết nối. Cần cài service riêng nếu muốn daemon tự chạy khi khởi động. `scripts/local-setup.sh` là installer suite, yêu cầu thư mục artifact đã đóng gói (`DAMX-Daemon/DAMX-Daemon`), không phải lệnh cài daemon trực tiếp từ cây source hiện tại.

## Điều khiển thermal profile

Repo có patch driver ANV15-52 qua EC tại `scripts/patches/linuwu-sense-anv15-52-ec-profile.patch`. Tuy nhiên daemon trước đó vẫn loại ANV15-52 khỏi feature `thermal_profile` và từ chối ghi profile.

Đã sửa `DAMM-Daemon/DAMX-Daemon.py` để daemon quảng bá/ghi profile khi:

- driver nhận diện được laptop Nitro hoặc Predator; và
- `/sys/firmware/acpi/platform_profile` đọc được giá trị đang dùng, giá trị đó có trong `/sys/firmware/acpi/platform_profile_choices`.

Đã bỏ chặn riêng ghi thermal profile cho ANV15-52. Sau sửa đổi, cần khởi động lại daemon chạy từ source để nạp code mới.

Kiểm tra trạng thái profile:

```sh
cat /sys/firmware/acpi/platform_profile
cat /sys/firmware/acpi/platform_profile_choices
```

Tại thời điểm kiểm tra, GUI gửi các lệnh `set_thermal_profile` và giá trị sysfs đã chuyển thành `balanced`. Vì vậy các nút đang hoạt động để đổi **thermal/performance profile**; tác động đến quạt phụ thuộc nhiệt độ và tải máy, không nhất thiết thấy RPM đổi ngay.

## Điều khiển quạt thủ công

- Dashboard đọc nhiệt độ/RPM từ `hwmon`; đọc telemetry không đồng nghĩa có quyền điều khiển quạt.
- GUI chỉ hiện panel quạt nếu daemon báo feature `fan_speed`; daemon đã được sửa để quảng bá feature khi driver tạo file này và gửi duty CPU/GPU theo định dạng `CPU,GPU`.
- RuSense dùng cùng driver Linuwu-Sense và ghi cùng sysfs `nitro_sense/fan_speed`: `0,0` là Auto, `100,100` là tối đa, các giá trị 1–100 là duty thủ công. Sau khi cập nhật, khởi động lại daemon để GUI nhận feature/lệnh mới.
- DAMX daemon yêu cầu chạy bằng root. Nếu lệnh ghi vẫn lỗi, kiểm tra daemon có đang chạy source mới không và xem `/var/log/DAMX_Daemon_Log.log`; app RuSense chạy user thường cần quyền udev riêng từ `../rusense/install.sh`, nhưng quyền đó không thay thế daemon DAMX đang chạy bằng root.

## GPU usage hiện `N/A`

Trong lần kiểm tra trước, `nvidia-smi` báo không giao tiếp được với NVIDIA driver. Dashboard trước đây đổi lỗi/đầu ra rỗng thành `0%`, gây hiểu nhầm là GPU đang rảnh; nay hiển thị `N/A` khi không có số liệu. Người dùng vừa chạy truy vấn bên dưới và nhận `0`, xác nhận truy vấn hiện hoạt động; `0%` là tải GPU tại thời điểm lấy mẫu. Nếu GPU đang chạy tác vụ nặng mà vẫn luôn `0`, kiểm tra lại khi tác vụ đó đang chạy:

```sh
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits --id=0
```

Ghi chú từ lần xử lý trước: `sudo nvidia-modprobe -c 0 -u` từng giúp `nvidia-smi` bắt đầu trả dữ liệu. Khi lệnh truy vấn trả số hợp lệ, DAMX có thể đọc GPU usage; nếu lệnh lại báo lỗi driver, ứng dụng sẽ không có dữ liệu và hiển thị `N/A`.

## Kiểm tra tiếp theo

```sh
cat /sys/class/dmi/id/product_name
lsmod | grep -E 'linuwu_sense|asense_rgb'
dkms status
modinfo linuwu_sense | head
cat /sys/firmware/acpi/platform_profile
cat /sys/firmware/acpi/platform_profile_choices
ls -l /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/nitro_sense
```

- Khi dùng Linuwu-Sense, xác nhận `linuwu_sense` đã nạp và `asense_rgb` không nạp.
- Nếu thermal profile không đổi, xem lỗi ghi trong `/var/log/DAMX_Daemon_Log.log` và kernel log (`sudo journalctl -k -b`).
- Không chạy lại installer Linuwu-Sense khi chưa kiểm tra `dkms status`/`modinfo`; ghi chú người dùng nêu installer cũ từng khai báo version `1.0.0` trong khi DKMS dùng `1.0`.
- Phân biệt `./install.sh` của RuSense (quy tắc udev) với script cài kernel module Linuwu-Sense.

## Lưu ý workspace

Đã có một số thay đổi chưa commit trong workspace ở nhiều file khác. Giữ nguyên các thay đổi đó khi tiếp tục; không dùng `git reset` hoặc khôi phục hàng loạt.
