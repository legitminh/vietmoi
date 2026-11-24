**Tiếng Việt** · [English](RELEASING.en.md)

# siêu việt 0.12.2 · bản dựng 39

Bản dùng thử dành cho macOS, iOS, Android, Windows và Ubuntu. Giao diện và tài liệu mặc định bằng tiếng Việt. Trong ứng dụng, mở **Cài đặt → Ngôn ngữ giao diện → English** để chuyển sang tiếng Anh. Lựa chọn được lưu và không đổi bố cục phím hay cách viết.

## Tải xuống và cài đặt

Chọn tệp phù hợp tại [GitHub Releases](https://github.com/legitminh/vietmoi/releases). `SHA256SUMS` chứa mã kiểm tra tệp; `BUILD-INFO.json` ghi nguồn mã và kết quả xác minh.

| Tệp tải xuống | Yêu cầu và cách cài |
| --- | --- |
| `macos-universal.zip` | macOS 13 trở lên, Apple Silicon hoặc Intel. Giải nén, chép `VietMoi.app` vào `~/Library/Input Methods/`, mở ứng dụng rồi vào **Cài đặt hệ thống → Bàn phím → Nhập văn bản → Sửa → +** để thêm **siêu việt**. Gói được ký tạm thời, chưa được Apple công chứng bằng Developer ID; macOS có thể yêu cầu bạn cho phép mở hoặc đăng nhập lại. Khi cập nhật từ mã nguồn, dùng `bash scripts/install.sh --no-build` để giữ đăng ký và nguồn nhập đang dùng. |
| `ios-unsigned.ipa` | iOS/iPadOS 16 trở lên. Có ứng dụng và tiện ích bàn phím, nhưng **chưa ký: phải ký lại cả hai bằng tài khoản Apple của bạn và cùng quyền App Group trước khi cài**. Đây không phải bản App Store, TestFlight hay bản cài OTA trực tiếp. Cách cài phát triển đơn giản nhất: mở `iOS/VietMobile.xcodeproj` bằng Xcode, chọn nhóm ký cho cả ứng dụng và bàn phím, rồi chạy trên thiết bị. Sau đó thêm siêu việt trong **Cài đặt → Cài đặt chung → Bàn phím → Bàn phím → Thêm bàn phím mới**. |
| `android-universal-debug.apk` | Android 10 trở lên (API 29), ARM64 hoặc x86_64. Mở APK và cho phép cài từ nguồn tải này nếu được hỏi. Mở siêu việt, bật bàn phím trong cài đặt Android rồi chọn siêu việt làm bàn phím. Đây là bản ký phát triển. Không cần quyền Internet. |
| `windows-x64.zip` / `windows-arm64.zip` | Windows 10/11 với kiến trúc tương ứng. Giải nén vào thư mục bạn sẽ giữ lâu dài. Gói có bộ xử lý Swift, thư viện chạy, bộ gõ TSF, ứng dụng cài đặt và chương trình kiểm tra. Mở PowerShell đúng kiến trúc bằng quyền quản trị, chạy `./install.ps1`, rồi chọn siêu việt bằng **Win+Space**. Mở `SieuvietSettings.exe` để cài đặt và gõ thử. Dùng `./install.ps1 -Language en` để xem thông báo cài bằng tiếng Anh; `./install.ps1 -Uninstall` để gỡ đăng ký. Các gói chưa ký đã qua kiểm tra bộ xử lý trên Windows thật; thao tác gõ TSF trong ứng dụng thực tế vẫn chưa được thẩm định. |
| `ubuntu-26.04-amd64.deb` / `ubuntu-26.04-arm64.deb` | Ubuntu 26.04, đúng kiến trúc. Chạy `sudo apt install ./ten-tep.deb`, thay `ten-tep.deb` bằng đúng tệp đã tải. Gói chứa IBus, Fcitx 5, ứng dụng cài đặt, bộ xử lý Swift, thư viện chạy và thông tin phụ thuộc. Sau khi cài, thêm siêu việt trong nguồn nhập IBus hoặc cấu hình Fcitx 5; chỉ dùng một hệ nhập trong mỗi phiên. Đăng nhập lại nếu cần. Các bản Ubuntu khác chưa được thẩm định. Gỡ bằng `sudo apt remove sieuviet`. |

## Bắt đầu gõ

Chọn **âm đầu → âm đệm + âm chính → âm cuối → thanh**. Chọn **∅** khi không có âm đầu hoặc âm cuối. Thanh là lựa chọn cuối; bàn phím ghi âm tiết hoàn chỉnh và một dấu cách.

Với bố cục ascii+, nhấn lần lượt `m s e d` để gõ **má**, `x v n s` để gõ **xin**. Với cách viết **quốc ngữ**, `f r e j` cho **phở**. Đây là các lần nhấn riêng, không phải tổ hợp nhấn đồng thời. Xóa lùi quay lại một lượt chọn khi đang ghép âm; dấu cách giữ phần chưa hoàn tất.

Mở ứng dụng → **Cài đặt** để chọn bố cục **ascii+ / grid4x8**, cách viết **siêu việt / quốc ngữ**, và ngôn ngữ giao diện. Trên bàn phím vật lý, nhấn riêng Shift trái thật nhanh để đổi giữa tiếng Việt và ASCII; giữ hoặc kết hợp Shift với phím khác vẫn hoạt động bình thường. Trên iPhone, chạm nhanh ⇧ để đổi chế độ; giữ ⇧ trong lúc gõ để viết hoa, chạm đúp để khóa chữ hoa. `123` và `#+=` mở số và ký hiệu.

Trên iPhone/iPad, giữ phím địa cầu để chọn siêu việt. **Không cần bật Quyền truy cập đầy đủ.** iOS dùng bàn phím Apple trong ô mật khẩu, một số ô số điện thoại hoặc ứng dụng chặn bàn phím bên thứ ba.

## Dữ liệu và giới hạn bản dùng thử

Cài đặt được lưu trên thiết bị. Bộ gõ không lưu nội dung bạn gõ, không có lịch sử gõ thường trực và không kết nối máy chủ. Đổi ngôn ngữ chỉ đổi giao diện và hướng dẫn.

Các bản dựng đã qua kiểm tra biên dịch, bộ xử lý dùng chung và các kiểm tra tích hợp được ghi trong `BUILD-INFO.json`. macOS chưa có Developer ID/công chứng; iOS cần ký lại; APK dùng chữ ký phát triển; kiểm tra gõ TSF tương tác trên Windows, thiết bị di động thật và phạm vi ứng dụng/Wayland rộng hơn vẫn còn cần thực hiện.

## Tự tạo bản dựng

Mã nguồn dùng chung ở `Sources/Core`. Yêu cầu và lệnh kiểm tra chi tiết nằm trong [tài liệu tiếng Anh dành cho nhà phát triển](RELEASING.en.md#reproduce-the-builds), [iOS](iOS/README.md), [Android](Android/README.md) và [Windows/Ubuntu](Desktop/README.md).

Trên macOS đã có Xcode cùng bộ công cụ Android:

```sh
python3 scripts/generate-design.py --check
bash scripts/package-apple-android.sh
```

Trình cài từ mã nguồn mặc định dùng tiếng Việt. Ví dụ dùng thông báo tiếng Anh:

```sh
SIEUVIET_LANGUAGE=en bash scripts/install.sh --no-build
```

Giữ nguyên mã định danh ứng dụng và `VietMoi.app` khi cập nhật. Không công khai khóa ký, hồ sơ cấp phép, bộ SDK, dữ liệu trình mô phỏng hoặc cài đặt cá nhân.
