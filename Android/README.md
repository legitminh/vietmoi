**Tiếng Việt** · [English](README.en.md)

# siêu việt cho Android

Bàn phím hệ thống, ứng dụng cài đặt và ô gõ thử cho Android 10 trở lên (API 29). APK dùng chung bộ xử lý Swift, không sao chép bảng âm sang Kotlin. Có bản phổ dụng cho ARM64 và x86_64.

## Cài và bật bàn phím

1. Tải `android-universal-debug.apk` từ [GitHub Releases](https://github.com/legitminh/vietmoi/releases).
2. Mở tệp. Nếu Android hỏi, cho phép cài ứng dụng từ nguồn tải này rồi xác nhận cài. Đây là APK ký phát triển, không phải bản cửa hàng.
3. Mở **siêu việt**, chọn **Bật bàn phím** và bật siêu việt trong cài đặt bàn phím Android.
4. Quay lại ứng dụng, chọn **Chọn bàn phím → siêu việt**. Chạm ô gõ thử để kiểm tra.

Không cần tài khoản Google hoặc dịch vụ trả phí để dùng bản cài cục bộ. Nếu chữ ký của bản đang cài khác với APK tải về, Android không cho cập nhật trực tiếp; xuất/ghi lại cài đặt bạn cần trước khi tự quyết định gỡ bản cũ. Không cần gỡ khi chữ ký khớp.

## Cách gõ

Chọn lần lượt **âm đầu → âm đệm + âm chính → âm cuối → thanh**; dùng ∅ cho âm vắng. Trên cảm ứng, chạm âm ghi trên phím. Với bàn phím vật lý, các ví dụ ascii+ là `msed → má`, `xvns → xin`, `frej → phở` khi dùng quốc ngữ. Sau mỗi âm tiết hoàn chỉnh có một dấu cách.

- Xóa lùi quay lại một lượt; khi không ghép âm thì xóa bình thường, kể cả văn bản có emoji.
- Dấu cách và chuyển chế độ giữ phần đang gõ dở, không tự đoán âm còn thiếu.
- Chọn ABC để gõ văn bản nguyên dạng. Số, ký hiệu, xuống dòng và thao tác của ô nhập dùng các phím tương ứng.
- Với bàn phím vật lý, nhấn riêng Shift trái thật nhanh để đổi tiếng Việt / ASCII; giữ hoặc dùng cùng phím khác vẫn là Shift. Giữ lặp phím thành phần không chuyển nhiều lượt.
- Phím Xóa của bố cục lưới chỉ xóa chu kỳ vừa ghi khi văn bản xung quanh khớp; không xóa dựa trên phỏng đoán.

Bảng âm chính có 24 lựa chọn: oo ở a, wê ở n, wi ở m; âm cuối o giữ nguyên. Xem [bảng phím đầy đủ](../README.md).

## Cài đặt và ngôn ngữ

Trong ứng dụng, chọn bố cục **ascii+ / grid4x8**, cách viết **siêu việt / quốc ngữ** và **Tiếng Việt / English**. Tiếng Việt là mặc định; ngôn ngữ được lưu, không đổi các lựa chọn gõ. Cài đặt mới được bộ gõ đọc khi kích hoạt; từ đang ghép giữ cấu hình đã bắt đầu.

Ứng dụng và tiến trình bàn phím tách nhau. Chỉ ứng dụng ghi bản cài đặt nguyên tử; bàn phím dùng bản trong bộ nhớ lúc gõ. Không có quyền Internet, phân tích sử dụng hay lịch sử gõ thường trực. Giao diện theo chế độ sáng/tối của hệ thống.

## Tạo bản dựng và kiểm tra

Trên máy Mac có Android SDK, Java và Xcode theo [tài liệu kỹ thuật tiếng Anh](README.en.md):

```sh
python3 scripts/setup-android-native.py
python3 scripts/build-android.py --tests
python3 scripts/android-emulator.py
python3 scripts/test-android.py --no-build
```

Công cụ tải trình biên dịch Swift, SDK Swift cho Android và NDK vào `build/android-tools`, không thay Xcode hay bộ công cụ hệ thống. Dùng `--abis arm64-v8a` với lệnh tạo bản dựng nếu chỉ cần ARM64. APK ở `Android/app/build/outputs/apk/debug/app-debug.apk`; bản phổ dụng lớn vì kèm thư viện Swift cho hai kiến trúc.

Trình mô phỏng riêng là **Sieuviet_API_36**, `emulator-5556`. Không đổi bàn phím của thiết bị khác. Khi điều khiển trình mô phỏng bằng bàn phím Mac, chọn nguồn nhập ABC trên Mac để tránh bộ gõ macOS biến đổi phím trước khi Android nhận. Kiểm tra trên Pixel/Samsung thật vẫn là công việc thẩm định riêng.
