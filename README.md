**Tiếng Việt** · [English](README.en.md)

# siêu việt

Bàn phím tiếng Việt cho **macOS, iOS, Android, Windows và Ubuntu**. Ghép âm tiết bằng bốn lượt chọn, dùng chung một bộ xử lý trên mọi nền tảng. Giao diện mặc định bằng tiếng Việt; chọn **English** trong **Cài đặt → Ngôn ngữ giao diện** nếu muốn dùng tiếng Anh. Lựa chọn được lưu riêng, không đổi chế độ nhập hay cách viết.

[Tải bản dùng thử](https://github.com/legitminh/vietmoi/releases) · [Cài đặt theo hệ điều hành](RELEASING.md) · [iPhone/iPad](iOS/README.md) · [Android](Android/README.md) · [Windows/Ubuntu](Desktop/README.md)

Phiên bản **0.14.0, bản dựng 41**. Đọc hướng dẫn phát hành trước khi cài: macOS được ký tạm thời, iOS phải ký lại, APK dùng chữ ký phát triển, Windows chưa được thẩm định gõ TSF tương tác trong ứng dụng thực tế.

## Cách gõ

1. Chọn **âm đầu**, kể cả ∅.
2. Chọn **âm đệm + âm chính** bằng một phím.
3. Chọn **âm cuối**, kể cả ∅. Lúc này xem được âm tiết chưa đặt thanh.
4. Chọn **thanh**. Bàn phím đặt thanh vào âm chính, ghi âm tiết và một dấu cách.

Trên màn hình cảm ứng, chạm âm đang hiện trên phím. Trên bàn phím vật lý, dùng vị trí phím theo bàn phím Hoa Kỳ; bảng gợi ý đổi sau mỗi lượt. Mỗi ký tự trong ví dụ dưới là một lần nhấn riêng.

| Phím chế độ siêu việt | Cách viết siêu việt | Cách viết quốc ngữ |
| --- | --- | --- |
| `mses` | ma | ma |
| `msed` | má | má |
| `xvns` | xin | xin |
| `frej` | fở | phở |
| `rwos` | răo | rau |
| `imoj` | khwỉo | khuỷu |
| `xaas` | xoong | xoong |
| `mlnd` | muốn | muốn |

## Chọn chế độ nhập và cách viết

Mở ứng dụng **siêu việt → Cài đặt**. Chế độ nhập mặc định **siêu việt** dùng ký hiệu âm như `f`, `z`, `w`. Chế độ nhập **quốc ngữ** dùng trực tiếp `ph`, `gi`, `oa`, `uô`, `ưa` và các tổ hợp chính tả khác trong bảng phím. Cả hai được dịch sang cùng một cấu trúc âm trước khi kết xuất, nên đổi chế độ nhập không thay đổi cách viết đã chọn.

Cách viết **siêu việt** giữ dạng phiên âm. **quốc ngữ** chuyển âm tiết hoàn chỉnh sang chính tả tiếng Việt ở lượt chọn thanh cuối cùng, ví dụ `ngiêng` → `nghiêng`, `fở` → `phở`, `khwỉo` → `khuỷu`. Ba lượt đầu vẫn dùng chung dạng xem trước. Dấu cách hoặc chuyển chế độ giữa chừng giữ nguyên phần chưa xong; bộ gõ không tự thêm âm hoặc tự chuyển cách viết cho một từ chưa hoàn tất.

Tên hồ sơ, chế độ nhập và cách viết được giữ khi đổi ngôn ngữ. Giao diện sáng/tối theo hệ thống. Trên macOS có thể thêm nhiều bàn phím trong ứng dụng, chọn bàn phím mặc định, hiện/ẩn bảng phím và điều chỉnh thời gian nhận nhấn nhanh Shift trái.

## Bảng phím chế độ siêu việt

Âm đầu: `b c ch d đ g z h k kh l m n ng nh p f r s t th tr v x q ∅`.
Các phím đặc biệt: `j → ch`, `y → d`, `d → đ`, `i → kh`, `a → ng`, `w → nh`, `u → th`, `e → tr`, `q → q`, `o → ∅`. Các âm còn lại dùng chữ tương ứng. **f** biểu diễn ph; **z** biểu diễn gi trong cách viết quốc ngữ.

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

## Bảng phím chế độ quốc ngữ

Âm đầu dùng cùng vị trí với chế độ siêu việt, với `z → gi`, `f → ph`, `a → ng`, `e → tr`, `q → q`, `o → ∅`. Âm chính: `a → oo`, `q → yê`, `w → ă`, `s → a`, `z → â`, `e → ia`, `d → e`, `x → ê`, `r → ơ`, `f → o`, `c → ô`, `t → ư`, `g → u`, `v → i`, `y → oă`, `h → oa`, `b → uâ`, `u → uya`, `j → oe`, `n → uê`, `i → uơ`, `m → ui`, `o → ươ`, `l → uô`, `p → ưa`.

Âm cuối thêm `u` ở phím `u` và `y` dùng chung vị trí `i`; các âm cuối còn lại và thanh giữ vị trí như chế độ siêu việt. Cả hai chế độ dùng `a → ng` ở lượt âm cuối. Ví dụ `q l c d → quốc`, trong khi `c l c d → cuốc`.

Âm cuối: `∅ c ch m n ng nh p t o i`. Các phím đặc biệt: `e → ∅`, `j → ch`, `a → ng`, `w → nh`; các âm khác dùng chữ tương ứng. Âm cuối **o** biểu diễn /w/, âm cuối **i** biểu diễn /j/.

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
- **Fn+Backspace / Delete tiến:** xóa phần đang ghép hoặc chu kỳ vừa ghi khi bộ gõ xác minh được văn bản và vị trí con trỏ. Vùng chọn rõ ràng dùng thao tác xóa của ứng dụng.
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


## Bàn phím đa ngôn ngữ và thao tác chạm (0.15.0)

Chọn **Ngôn ngữ bàn phím** trước, rồi chọn chế độ nhập và cách viết tương ứng. Có tiếng Anh (QWERTY), tiếng Việt (siêu việt hoặc quốc ngữ) và tiếng Trung (Microsoft Shuangpin → chữ Hán giản thể). Nhấn nhanh Shift trái để đổi bàn phím. Cả ứng dụng lẫn chế độ nhập/xuất tùy chỉnh đều mang tên **siêu việt**.

Mỗi bàn phím lưu riêng lựa chọn **Gợi ý hoàn tất**. Gợi ý chạy nền, không chặn việc gõ và bỏ kết quả đã lỗi thời. Tắt hoàn tất tiếng Trung vẫn giữ danh sách chữ Hán để chuyển đổi; ví dụ `nihk` + dấu cách → 你好. Bàn phím ảo Shuangpin trên Mac có tùy chọn hiện/ẩn riêng.

Các phím có màu trung tính. Vùng nhận chạm phủ kín các khoảng hở nhìn thấy; giữ phím chữ sẽ hiện chữ phóng to, trượt sang phím khác rồi thả để chọn phím đó. Shift và Delete giữ cách hoạt động riêng. Giữ dấu cách rồi kéo trái/phải hoặc lên/xuống để di chuyển con trỏ. Trình soạn thảo trong ứng dụng dùng dòng hiển thị; bàn phím hệ thống dùng ngữ cảnh xuống dòng mà iOS cho phép truy cập.
