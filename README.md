# FinvorasGen 🚀

Công cụ CLI nội bộ hỗ trợ phát triển Flutter: khởi tạo dự án chuẩn, sinh code type-safe cho assets, và setup branding đa môi trường.

---

## 🛠 Cài đặt

Vì đây là công cụ nội bộ, cài đặt trực tiếp từ source:

```sh
# Clone repo
git clone <repo-url> finvoras_gen
cd finvoras_gen

# Cài đặt global
dart pub global activate --source path .
```

Đảm bảo `~/.pub-cache/bin` có trong `PATH` của bạn.

---

## 🚀 Các lệnh

### `init` — Khởi tạo dự án mới

Tự động hoá toàn bộ setup ban đầu cho một Flutter project chuẩn Finvoras.

```sh
finvoras_gen init <app-id>

# Ví dụ
finvoras_gen init vn.com.finvoras.myapp
```

**Các bước tự động thực hiện:**

1. Chạy `flutter create` với `--org` và `--project-name` từ `<app-id>`.
2. Clone submodule nội bộ `packages` từ GitHub.
3. Link các local packages vào `pubspec.yaml` (workspace + dependencies).
4. Ghi cấu hình `finvoras_gen` vào `pubspec.yaml` (output, assets, locales...).
5. Thêm bộ package chuẩn: `injectable`, `get_it`, `equatable`, `build_runner`,...
6. Tạo `melos.yaml` cho monorepo.
7. Tạo thư mục `assets/images/` và `assets/locales/`.
8. Cập nhật `ios/Podfile` lên platform `15.0`.
9. Chạy `flutter pub get`.

> **Lưu ý:** Nếu thư mục `packages/` đã tồn tại, lệnh sẽ hỏi xác nhận trước khi tiếp tục.

---

### `branding` — Setup flavors, splash & icons

Tự động cấu hình `flutter_flavorizr`, native splash screen và launcher icons cho tất cả môi trường.

```sh
# Mặc định: dev, qa, prod — behavior mode (chung Application ID)
finvoras_gen branding

# Tùy chỉnh environments
finvoras_gen branding --envs dev,staging,prod

# Platform mode: mỗi flavor có Application ID riêng (thêm suffix .<env>)
finvoras_gen branding --type platform --envs dev,stg,prod

# Chỉ định đường dẫn logo
finvoras_gen branding --logo assets/images/my_logo.png

# CI mode: bỏ qua tất cả confirmation prompts
finvoras_gen branding --yes
```

**Options:**

| Flag | Viết tắt | Mặc định | Mô tả |
|---|---|---|---|
| `--type` | `-t` | `behavior` | `behavior` (chung 1 App ID) hoặc `platform` (mỗi flavor 1 App ID) |
| `--envs` | `-e` | `dev,qa,prod` | Danh sách môi trường, phân cách bằng dấu phẩy |
| `--logo` | | `assets/images/logo.png` | Đường dẫn đến file ảnh logo |
| `--yes` | `-y` | `false` | Bỏ qua confirmation (dùng cho CI) |
| `--dry-run` | | `false` | Xem trước thay đổi mà không ghi file |

**Các bước tự động thực hiện:**

1. Đọc `app_id` từ `finvoras_gen.app_id` trong `pubspec.yaml`.
2. Ghi cấu hình `flavorizr` vào `pubspec.yaml`.
3. Tạo `flutter_native_splash-<env>.yaml` và `flutter_launcher_icons-<env>.yaml` cho từng môi trường.
4. Thêm dev dependencies: `flutter_flavorizr`, `flutter_native_splash`, `flutter_launcher_icons`.
5. Chạy `flutter_flavorizr`, sinh splash và icons cho từng môi trường.

---

### `prepare` — Setup code, DI & localization

Chuẩn bị cấu trúc code, thiết lập Dependency Injection, sinh file ngôn ngữ và cấu hình khởi tạo cho dự án.

```sh
# Mặc định: stack bloc + go_router
finvoras_gen prepare

# Chọn stack GetX
finvoras_gen prepare --stack getx
```

**Options:**

| Flag | Viết tắt | Mặc định | Mô tả |
|---|---|---|---|
| `--stack` | `-s` | `bloc` | Lựa chọn state management: `bloc` (kèm `go_router`) hoặc `getx` |

**Các bước tự động thực hiện:**

1. Tạo thư mục `assets/locales/` và file JSON mẫu: `en.json`, `vi.json`.
2. Tạo `lib/src/di/injection.dart` (GetIt + Injectable).
3. Tạo `lib/core/config/prepare.dart` chứa logic khởi tạo (Splash screen, System UI, DI, Services init...).
4. Cập nhật `lib/main.dart`:
   - Bao bọc ứng dụng bằng `AppOrchestrator`.
   - Setup `MaterialApp.router` + `GoRouter` (nếu dùng bloc) hoặc `GetMaterialApp` (nếu dùng getx).
5. Thêm dependencies cần thiết theo stack đã chọn.
6. Chạy `flutter pub get`.
7. Chạy `finvoras_gen assets` nội bộ để sinh code translation.
8. Chạy `build_runner` để sinh code DI.

---

### `assets` — Sinh code type-safe cho assets

Sinh các class Dart type-safe từ cấu hình `finvoras_gen` trong `pubspec.yaml`.

```sh
# Sử dụng pubspec.yaml mặc định
finvoras_gen assets

# Chỉ định file pubspec tùy chỉnh
finvoras_gen assets --config path/to/pubspec.yaml

# Kết hợp với build.yaml
finvoras_gen assets --config pubspec.yaml --build build.yaml
```

**Options:**

| Flag | Viết tắt | Mặc định | Mô tả |
|---|---|---|---|
| `--config` | `-c` | `pubspec.yaml` | Đường dẫn đến file pubspec.yaml |
| `--build` | `-b` | | Đường dẫn đến file build.yaml |

---

### `refresh` — Dọn dẹp & lấy lại dependencies

Hữu ích sau khi đổi branch hoặc gặp lỗi cache.

```sh
finvoras_gen refresh
```

Tự động chạy `flutter clean` rồi `flutter pub get`.

---

### `version` — Xem phiên bản

```sh
finvoras_gen version
# hoặc
finvoras_gen -v
finvoras_gen --version
```

---

## 📝 Cấu hình `pubspec.yaml`

Sau khi chạy `init`, cấu hình sau sẽ được tự động thêm vào `pubspec.yaml` của dự án đích:

```yaml
finvoras_gen:
  app_id: vn.com.finvoras.myapp   # Application ID — dùng bởi branding command
  output: lib/generated/           # Thư mục xuất file sinh code
  line_length: 80
  assets:
    enabled: true
    outputs:
      class_name: AppAssets
  locales:
    enabled: true
    folder: assets/locales
    outputs:
      translation_name: AppTranslation
      keys_name: AppLocalesKeys
  integrations:
    flutter_svg: true
    lottie: true
```

---

## 🔗 Submodule Packages

Lệnh `init` sẽ clone repository packages nội bộ vào thư mục `packages/`:

```
https://github.com/hoangsang17th/packages
```

---

## 🧪 Kiểm thử nhanh

```bash
# Tạo thư mục test, chạy init trong đó
mkdir /tmp/test_app && cd /tmp/test_app
finvoras_gen init vn.io.enth17.chopchop

# Setup branding sau khi init
finvoras_gen branding
```