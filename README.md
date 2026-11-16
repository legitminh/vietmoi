**Tiếng Việt** · [English](README.en.md)

# siêu việt

Bàn phím tiếng Việt cho **macOS, iOS, Android, Windows và Ubuntu**. Ghép âm tiết bằng bốn lượt chọn, dùng chung một bộ xử lý trên mọi nền tảng. Giao diện mặc định bằng tiếng Việt; chọn **English** trong **Cài đặt → Ngôn ngữ giao diện** nếu muốn dùng tiếng Anh. Lựa chọn được lưu riêng, không đổi bố cục hay cách viết.

[Tải bản dùng thử](https://github.com/legitminh/vietmoi/releases) · [Cài đặt theo hệ điều hành](RELEASING.md) · [iPhone/iPad](iOS/README.md) · [Android](Android/README.md) · [Windows/Ubuntu](Desktop/README.md)

Phiên bản **0.12.2, bản dựng 39**. Đọc hướng dẫn phát hành trước khi cài: macOS được ký tạm thời, iOS phải ký lại, APK dùng chữ ký phát triển, Windows chưa được thẩm định gõ TSF tương tác trong ứng dụng thực tế.

## Cách gõ

1. Chọn **âm đầu**, kể cả ∅.
2. Chọn **âm đệm + âm chính** bằng một phím.
3. Chọn **âm cuối**, kể cả ∅. Lúc này xem được âm tiết chưa đặt thanh.
4. Chọn **thanh**. Bàn phím đặt thanh vào âm chính, ghi âm tiết và một dấu cách.

Trên màn hình cảm ứng, chạm âm đang hiện trên phím. Trên bàn phím vật lý, dùng vị trí phím theo bàn phím Hoa Kỳ; bảng gợi ý đổi sau mỗi lượt. Mỗi ký tự trong ví dụ dưới là một lần nhấn riêng.

| Phím ascii+ | Cách viết siêu việt | Cách viết quốc ngữ |
| --- | --- | --- |
| `mses` | ma | ma |
| `msed` | má | má |
| `xvns` | xin | xin |
| `frej` | fở | phở |
| `rwos` | răo | rau |
| `imoj` | khwỉo | khuỷu |
| `xaqs` | xoong | xoong |
| `mlnd` | muốn | muốn |

## Chọn bố cục và cách viết

Mở ứng dụng **siêu việt → Cài đặt**. **ascii+** ghép âm theo vị trí chữ; **grid4x8** sắp lựa chọn trên lưới bốn hàng, tám cột. Hai bố cục cùng dùng các âm, bốn lượt chọn và quy tắc thanh.

Cách viết **siêu việt** giữ dạng phiên âm. **quốc ngữ** chuyển âm tiết hoàn chỉnh sang chính tả tiếng Việt ở lượt chọn thanh cuối cùng, ví dụ `ngiêng` → `nghiêng`, `fở` → `phở`, `khwỉo` → `khuỷu`. Ba lượt đầu vẫn dùng chung dạng xem trước. Dấu cách hoặc chuyển chế độ giữa chừng giữ nguyên phần chưa xong; bộ gõ không tự thêm âm hoặc tự chuyển cách viết cho một từ chưa hoàn tất.

Tên hồ sơ, lựa chọn bố cục và cách viết được giữ khi đổi ngôn ngữ. Giao diện sáng/tối theo hệ thống. Trên macOS có thể thêm nhiều bàn phím trong ứng dụng, chọn bàn phím mặc định, hiện/ẩn bảng phím và điều chỉnh thời gian nhận nhấn nhanh Shift trái.

## Bảng phím ascii+

Âm đầu: `b c ch d đ g z h k kh l m n ng nh p f r s t th tr v x ∅`.
Các phím đặc biệt: `j → ch`, `y → d`, `d → đ`, `i → kh`, `q → ng`, `w → nh`, `u → th`, `o → tr`, `e → ∅`. Các âm còn lại dùng chữ tương ứng. **f** biểu diễn ph; **z** biểu diễn gi trong cách viết quốc ngữ.

| Phím | Có âm đệm w | Phím | Không có âm đệm |
| --- | --- | --- | --- |
| y | wă | w | ă |
| h | wa | s | a |
| b | wâ | z | â |
| u | wiê | e | iê |
| j | we | d | e |
| n | wê | x | ê |
| i | wơ | r | ơ |
| k | wo | f | o |
| m | wi | c | ô |
| | | t | ư |
| | | g | u |
| | | v | i |
| | | o | ươ |
| | | l | uô |
| | | a | oo |

Lượt âm chính có **24 lựa chọn**: wê ở n, wi ở m, oo ở a. Không có wô, wư hoặc wu. Phím p và q chưa gán ở lượt này; nhấn chúng không chuyển lượt. Dấu chấm phẩy là dấu câu thông thường.

Âm cuối: `∅ c ch m n ng nh p t o i`. Các phím đặc biệt: `e → ∅`, `j → ch`, `q → ng`, `w → nh`; các âm khác dùng chữ tương ứng. Âm cuối **o** biểu diễn /w/, âm cuối **i** biểu diễn /j/.

| Thanh | ngang | sắc | huyền | hỏi | ngã | nặng |
| --- | --- | --- | --- | --- | --- | --- |
| Phím | s | d | f | j | k | l |

Thanh luôn đặt trên âm chính, không đặt trên âm đệm hoặc âm cuối. Vị trí mặc định với các nguyên âm ghép là iế, ướ, uố và oó. Bàn phím cho phép tự do ghép các lựa chọn, không dùng từ điển để chặn tổ hợp lạ.

## Cách chuyển sang quốc ngữ

- f/z chuyển thành ph/gi; g/ng thành gh/ngh trước nguyên âm trước. c/k thành k trước nguyên âm trước và qu khi có âm đệm w. Âm i chung trong gi+i/iê chỉ viết một lần.
- Âm đệm w viết o trước a/ă/e, u ở các vị trí khác và sau q. i/iê có âm đệm dùng y/ya/yê.
- Âm cuối o (/w/) viết o sau a dài/e, u ở các vị trí khác. ă ngắn thành a trong au/ay; âm cuối i viết y sau ă/â, còn lại viết i. a dài vẫn phân biệt trong ao/ai.
- iê/uô/ươ mở thành ia/ua/ưa; khi có âm cuối thì giữ iê/uô/ươ. yê dùng sau u hoặc đầu âm tiết. Lựa chọn oo vẫn là oo.
- Âm cuối c/ng theo cách phát âm Hà Nội sau e/ê/i dùng ch/nh; e trong các vần này viết a, như ach/anh. Vẫn có thể chọn trực tiếp ch/nh.
- Thanh ở nguyên âm chính: hoá/huỷ, iế/uố/ướ và ía/úa/ứa khi không có âm cuối. Quy ước i đứng riêng dùng y; phụ âm thông thường đi với i vẫn dùng i.

Đây là chuyển cách viết từ cấu trúc âm, không phải sửa theo từ điển. Bộ gõ không hợp nhất các âm đã chọn theo phương ngữ, không chặn tổ hợp lạ, kể cả thanh ngang với âm cuối t. Ví dụ oo giữ xoong/boong/soóc riêng với o.

## Sửa, chuyển chế độ và viết hoa

- **Nhấn riêng Shift trái thật nhanh:** đổi tiếng Việt / ASCII khi nhả phím. Giữ phần đang gõ, kết thúc chu kỳ mà không thêm dấu cách. Giữ Shift hoặc dùng cùng phím khác vẫn là Shift thông thường; Shift phải không đổi chế độ.
- **Dấu cách:** giữ phần chưa hoàn tất, thêm một dấu cách và bắt đầu chu kỳ mới.
- **Xóa lùi:** khi đang ghép âm, lùi lại một lượt; ngoài lúc ghép âm, xóa bình thường.
- **Escape:** hủy phần đang ghép và khôi phục vùng chọn đã thay nếu ứng dụng hỗ trợ.
- **Fn+Backspace / Delete tiến:** trong ascii+, xóa phần đang ghép hoặc chu kỳ vừa ghi khi bộ gõ xác minh được văn bản và vị trí con trỏ. Vùng chọn rõ ràng dùng thao tác xóa của ứng dụng.
- **Shift+Backspace / Shift+Delete:** hủy phần đang ghép và thử xóa chu kỳ chữ trước đó cùng dấu phân cách theo khả năng của ứng dụng.
- **Return, Tab, điều hướng và phím tắt:** giữ phần nhìn thấy rồi trả thao tác cho ứng dụng. Chuyển ô nhập không phát lại văn bản vào ô mới.
- **Phím không có lựa chọn:** không chuyển lượt. Giữ lặp một phím thành phần không tự đi qua nhiều lượt.

Trên iPhone/iPad, chạm nhanh ⇧ để đổi chế độ; giữ ⇧ trong khi gõ để viết hoa; chạm đúp để khóa chữ hoa, chạm lại để tắt. Chạm `123` hoặc `#+=` để mở số/ký hiệu; giữ để dùng tạm thời rồi nhả để trở lại. Giữ phím xóa để xóa lặp. Dùng phím địa cầu của hệ thống để chuyển bàn phím.

Tự động viết hoa từ và bộ gõ Telex chưa được triển khai. Khả năng sửa/xóa phụ thuộc giao thức của ứng dụng nhận văn bản; bộ gõ từ chối xóa khi không xác minh được ngữ cảnh.

## Cài đặt và quyền riêng tư

Xem [hướng dẫn cài từng nền tảng](RELEASING.md). Tên hiển thị là **siêu việt**. Trên macOS giữ nguyên `com.minh.inputmethod.VietMoi` và `~/Library/Input Methods/VietMoi.app` để tương thích cập nhật; lối mở ứng dụng là `~/Applications/siêu việt.app`.

iOS không cần **Quyền truy cập đầy đủ**. Bàn phím hoạt động khi đóng ứng dụng; iOS có thể thay bằng bàn phím Apple trong ô bảo mật hoặc ứng dụng không cho phép bàn phím bên thứ ba. Android không yêu cầu quyền Internet. Cài đặt được lưu cục bộ, không có máy chủ, phân tích sử dụng hoặc nhật ký nội dung gõ.

## Mã nguồn và kiểm tra

Các nền tảng chia sẻ bộ xử lý Swift tại `Sources/Core`, dữ liệu giao diện song ngữ ở `Design/content.json`, và thương hiệu/phiên bản ở `Design/brand.json`. Văn bản được xuất dưới dạng Unicode NFC. Bộ xử lý giữ cấu trúc âm đầu, âm đệm, âm chính, âm cuối và thanh riêng với cách viết.

Chi tiết kỹ thuật, kiến trúc, ánh xạ tùy chỉnh và lệnh kiểm tra đầy đủ: [README tiếng Anh](README.en.md), [kế hoạch đa nền tảng](CROSS_PLATFORM.md) và [biên bản xác minh](VERIFICATION.md). Các tài liệu kế hoạch và biên bản là ghi chép dành cho nhà phát triển.
