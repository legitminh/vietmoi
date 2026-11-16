**Tiếng Việt** · [English](README.en.md)

# siêu việt cho iPhone và iPad

Ứng dụng và tiện ích bàn phím dùng chung bộ xử lý với macOS và Android. Yêu cầu iOS/iPadOS 16 trở lên; bộ kiểm tra giao diện dành cho nhà phát triển cần iOS 17 trở lên.

## Cài ứng dụng

Bản IPA trong [GitHub Releases](https://github.com/legitminh/vietmoi/releases) **chưa ký**. Không thể cài trực tiếp: ký lại cả ứng dụng và `VietKeyboard.appex` bằng tài khoản Apple của bạn, với quyền App Group trùng nhau. Gói không phải bản App Store hay TestFlight.

Để cài phát triển bằng Xcode trên Mac:

1. Kết nối iPhone/iPad, mở khóa và xác nhận tin cậy máy Mac nếu được hỏi.
2. Bật **Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển**; khởi động lại và xác nhận nếu thiết bị yêu cầu.
3. Mở `iOS/VietMobile.xcodeproj`, chọn scheme `VietMobile` và thiết bị của bạn.
4. Trong **Signing & Capabilities**, chọn nhóm Apple của bạn cho cả `VietMobile` và `VietKeyboard`, giữ ký tự động. Hai mã gói phải cùng tiền tố; nếu đổi, hãy đổi đồng bộ. Bật cùng nhóm `group.com.minh.sieuviet.ios` cho cả hai.
5. Chạy ứng dụng. Nếu được hỏi, tin cậy danh tính phát triển trong **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị**.

Tài khoản Apple miễn phí có thể cài phát triển trên thiết bị cá nhân. Hồ sơ Personal Team có thời hạn ngắn, thường bảy ngày; tạo bản dựng và cài lại để gia hạn. Phân phối App Store/TestFlight cần tư cách thành viên trả phí. Nếu hồ sơ cũ thiếu quyền App Group, cho Xcode đăng ký nhóm và làm mới hồ sơ.

## Bật bàn phím hệ thống

Mở **Cài đặt → Cài đặt chung → Bàn phím → Bàn phím → Thêm bàn phím mới → siêu việt**. Trong ô nhập, giữ phím địa cầu và chọn siêu việt. Để **Quyền truy cập đầy đủ** ở trạng thái tắt.

Ứng dụng có ô gõ thử tích hợp và một ô dùng bàn phím hệ thống để thử tiện ích thật. Nút **Bật bàn phím** nhắc lại các bước trên. iOS dùng bàn phím Apple trong ô mật khẩu, một số ô điện thoại hoặc ứng dụng không cho phép bàn phím bên thứ ba.

## Sử dụng

Chọn **âm đầu → âm đệm + âm chính → âm cuối → thanh**. ∅ là không có âm đầu/âm cuối. Chọn thanh cuối để ghi âm tiết cùng một dấu cách. Với quốc ngữ, chọn `f → ơ → ∅ → hỏi` để gõ **phở**. Xem [bảng phím và ví dụ](../README.md).

- Xóa lùi lùi một lượt khi đang ghép, xóa thông thường khi không ghép; giữ để xóa lặp.
- Dấu cách giữ phần chưa hoàn tất. Chuyển ô không phát lại phần đang ghép vào ô khác.
- Chạm nhanh ⇧ để đổi tiếng Việt / ASCII. Ứng dụng gõ thử và tiện ích hệ thống lưu chế độ riêng.
- Giữ ⇧ khi gõ để viết hoa chữ đầu của phím; nhả thì trở lại bình thường. Chạm đúp để khóa chữ hoa, chạm lại để tắt.
- `123` và `#+=` mở số/ký hiệu; giữ một trong hai để dùng tạm thời, nhả để về bố cục trước.
- Dấu cách để trống và Return dùng biểu tượng; cả hai có nhãn trợ năng theo ngôn ngữ giao diện.

## Cài đặt và ngôn ngữ

Mở ứng dụng → **Cài đặt** để chọn **ascii+ / grid4x8**, **siêu việt / quốc ngữ**, hoặc **Tiếng Việt / English**. Tiếng Việt là mặc định. Đổi ngôn ngữ không đổi âm, bố cục hay cách viết.

Ứng dụng lưu một bản cài đặt nhỏ trong App Group. Tiện ích đọc khi kích hoạt, giữ cài đặt trong bộ nhớ khi gõ và không cần ứng dụng mở. Chế độ ASCII lưu trong vùng riêng của tiện ích. Không ghi nội dung bạn gõ, không phân tích sử dụng, không kết nối mạng và không cần Quyền truy cập đầy đủ.

## Tạo bản dựng và kiểm tra

Từ thư mục dự án:

```sh
bash scripts/build-ios.sh simulator
bash scripts/build-ios.sh device TEAM_ID DEVICE_ID
bash scripts/install-ios.sh DEVICE_ID --no-build
bash scripts/test-mobile.sh
```

Thay `TEAM_ID` và `DEVICE_ID` bằng giá trị của bạn. Bản thiết bị tạo khi không có nhóm ký chỉ là kiểm tra biên dịch, không cài được. Thêm `SIEUVIET_LANGUAGE=en` trước lệnh cài để dùng thông báo tiếng Anh. Xem [tài liệu kỹ thuật tiếng Anh](README.en.md) cho kiểm tra tiện ích thật, chuyển cài đặt và lệnh Xcode chi tiết.
