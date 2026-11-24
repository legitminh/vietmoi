**Tiếng Việt** · [English](README.en.md)

# siêu việt trên Windows và Ubuntu

Hai nền tảng dùng cùng bộ xử lý Swift qua C ABI, không có bản sao bảng âm hay quy tắc chính tả bằng C++. Tiếng Việt là ngôn ngữ giao diện mặc định; chọn **English** trong ứng dụng cài đặt để đổi ngôn ngữ mà không đổi bố cục/cách viết.

## Windows

Tải ZIP **x64** hoặc **ARM64** đúng kiến trúc tại [GitHub Releases](https://github.com/legitminh/vietmoi/releases). Giải nén vào thư mục sẽ giữ lâu dài vì đăng ký bộ gõ trỏ đến đường dẫn của DLL. Gói có bộ xử lý và thư viện Swift, thư viện Visual C++, bộ gõ TSF, ứng dụng cài đặt và chương trình kiểm tra.

1. Mở PowerShell cùng kiến trúc bằng quyền quản trị, chuyển đến thư mục vừa giải nén.
2. Chạy `./install.ps1`. Trình cài kiểm tra bộ xử lý trước, chỉ đăng ký nếu kiểm tra đạt. Thông báo mặc định bằng tiếng Việt; dùng `./install.ps1 -Language en` để chuyển sang tiếng Anh.
3. Dùng **Win+Space** để chọn siêu việt; trình cài không tự đặt làm bàn phím mặc định.
4. Mở `SieuvietSettings.exe` để chọn bố cục, cách viết, ngôn ngữ và gõ thử.

Gỡ đăng ký bằng `./install.ps1 -Uninstall`. Đóng ứng dụng đang dùng bộ gõ trước khi xóa thư mục gói. Cài đặt cá nhân vẫn ở `%APPDATA%\Sieuviet\settings.conf`.

**Trạng thái:** x64 và ARM64 đã được tạo bằng Swift/MSVC trên máy Windows cùng kiến trúc và vượt qua kiểm tra bộ xử lý đã đóng gói. Kiểm tra đăng ký/gỡ TSF, gõ tương tác trong ứng dụng thực tế, ô mật khẩu, nâng cấp và các loại ứng dụng rộng hơn chưa hoàn tất. Đây là bản dùng thử chưa ký, không phải bộ cài đã được thẩm định đầy đủ; ứng dụng 32-bit và AppContainer/Store chưa được xác nhận.

## Ubuntu 26.04

Chọn `.deb` **amd64** hoặc **arm64** đúng máy. Ví dụ:

```sh
sudo apt install ./sieuviet-0.12.2-ubuntu-26.04-amd64.deb
```

Nếu dùng ARM64, thay tên bằng tệp `arm64` đã tải. `apt` cài các gói phụ thuộc; thư viện Swift đã nằm trong gói. Gói được tạo cho Ubuntu 26.04, không phải bộ cài Linux phổ dụng.

Đăng nhập lại nếu cần, rồi chọn một hệ nhập cho phiên của bạn:

- **IBus:** thêm siêu việt trong phần nguồn nhập của GNOME/IBus.
- **Fcitx 5:** thêm siêu việt trong ứng dụng cấu hình Fcitx 5.

Mở `sieuviet-settings` để chọn bố cục **ascii+ / grid4x8**, cách viết **siêu việt / quốc ngữ** và **Tiếng Việt / English**. Cài đặt ở `$XDG_CONFIG_HOME/sieuviet/settings.conf`, thường là `~/.config/sieuviet/settings.conf`. Các thay đổi áp dụng khi kích hoạt hoặc ở ranh giới từ; từ đang gõ không đổi cấu hình giữa chừng. Gỡ bằng `sudo apt remove sieuviet`.

**Trạng thái:** ARM64 và x64 đã qua kiểm tra bộ xử lý, cài gói và gõ thật qua IBus/Fcitx trong GTK/Qt trên X11. x64 được chạy qua mô phỏng trong vùng chứa trên máy phát triển Apple Silicon. GNOME/KDE Wayland, trình duyệt, terminal, các bản phân phối và ứng dụng khác vẫn cần thẩm định riêng.

## Dùng bàn phím

Chọn âm đầu → âm đệm + âm chính → âm cuối → thanh. Ví dụ ascii+: `msed → má`, `frej → phở` khi chọn quốc ngữ. Xóa lùi lùi một lượt, Escape hủy phần đang ghép, Shift trái nhấn riêng thật nhanh đổi ASCII, dấu cách giữ phần chưa hoàn tất. Delete chỉ xóa chu kỳ đã ghi khi bộ gõ xác minh được văn bản và con trỏ. Đổi ô nhập không phát lại từ đang gõ vào ô mới.

Bộ gõ dùng vùng ghép văn bản của hệ thống; không thay clipboard, không giả lập gõ phím và không dùng móc bàn phím toàn cục. Không lưu nội dung gõ, không kết nối máy chủ. Xem [hướng dẫn sử dụng chung](../README.md).

## Dành cho nhà phát triển

Trên Ubuntu theo kiến trúc cần tạo:

```sh
python3 scripts/build-linux.py --prefix /usr --destdir build/linux-system-root
python3 scripts/package-ubuntu.py
```

Trên Windows, mở Visual Studio Developer PowerShell cùng kiến trúc, cài Swift theo `.swift-version` rồi chạy:

```powershell
./scripts/build-windows.ps1 -Architecture x64
./scripts/build-windows.ps1 -Architecture ARM64
```

Chỉ chạy lệnh ứng với kiến trúc máy bạn. [README tiếng Anh](README.en.md) có yêu cầu thư viện, vùng chứa Ubuntu, kiểm tra GTK/Qt, cách tạo bản chéo và phạm vi cần thẩm định. [Hướng dẫn phát hành](../RELEASING.md) mô tả chữ ký và giới hạn tải xuống.
