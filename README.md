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
dart pub global deactivate finvoras_gen
dart pub global activate --source path .
finvoras_gen refresh
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
10. Tự động chạy `pod install --repo-update` trong thư mục `ios` để cập nhật CocoaPods.

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

# Tùy chỉnh tên hiển thị của ứng dụng (nếu không, sẽ tự động format từ pubspec.yaml)
finvoras_gen branding --name "Siêu Ứng Dụng"

# CI mode: bỏ qua tất cả confirmation prompts
finvoras_gen branding --yes
```

**Options:**

| Flag | Viết tắt | Mặc định | Mô tả |
|---|---|---|---|
| `--type` | `-t` | `behavior` | `behavior` (chung 1 App ID) hoặc `platform` (mỗi flavor 1 App ID) |
| `--envs` | `-e` | `dev,qa,prod` | Danh sách môi trường, phân cách bằng dấu phẩy |
| `--logo` | | `assets/images/logo.png` | Đường dẫn đến file ảnh logo |
| `--name` | `-n` | `Auto-format` | Tên hiển thị của ứng dụng trên iOS/Android |
| `--yes` | `-y` | `false` | Bỏ qua confirmation (dùng cho CI) |
| `--dry-run` | | `false` | Xem trước thay đổi mà không ghi file |

**Các bước tự động thực hiện:**

1. Đọc `app_id` từ `finvoras_gen.app_id` trong `pubspec.yaml`.
2. Ghi cấu hình `flavorizr` vào `pubspec.yaml`.
3. Tạo `flutter_native_splash-<env>.yaml` và `flutter_launcher_icons-<env>.yaml` cho từng môi trường.
4. Thêm dev dependencies: `flutter_flavorizr`, `flutter_native_splash`, `flutter_launcher_icons`.
5. Chạy `flutter_flavorizr`, sinh splash và icons cho từng môi trường.

> **Lưu ý:** Khi sử dụng flavors, bạn cần build app với flag `--flavor <name>` (ví dụ: `flutter build appbundle --flavor prod`). Lệnh `fastlane` của công cụ này đã được cấu hình để tự động xử lý việc này.

---

### `prepare` — Monorepo project bootstrap

Lệnh `prepare` đóng vai trò là "one-shot bootstrap" để thiết lập ứng dụng monorepo một cách hoàn chỉnh. 

```sh
# Chạy chuẩn bị cho toàn bộ workspace với FVM
finvoras_gen prepare --runtime fvm --workspace all --yes

# Chỉ định runtime flutter mặc định
finvoras_gen prepare --runtime flutter
```

**Options:**

| Flag | Viết tắt | Mặc định | Mô tả |
|---|---|---|---|
| `--runtime` | `-r` | | Bắt buộc: `flutter` hoặc `fvm` |
| `--workspace` | `-w` | `all` | `all`, `root`, hoặc danh sách: `packages/a,packages/b` |
| `--yes` | `-y` | `false` | Chạy non-interactive |

**Pipeline của `prepare`:**

1. Đọc cấu hình từ `ProjectSpec` (nhận dạng monorepo, app name,...).
2. Sử dụng Mustache template engine để render các file critical: `lib/main.dart`, `lib/app.dart` (bọc `AppOrchestrator`), `lib/core/configs/di.dart`, `lib/core/configs/prepare_environment.dart`.
3. Chuẩn hoá cấu hình monorepo trong `pubspec.yaml` (`workspace`, local package paths, `finvoras_gen`, `melos.scripts`).
4. Root dependency sync (`pub get`).
5. Package dependency sync cho workspace đã chọn.
6. Codegen package (`build_runner`, `finvoras_gen assets` nếu package có cấu hình).
7. Codegen root.
8. Verify + in summary `done/failed/skipped` theo từng step.

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

### `fastlane` — Setup deployment scripts

Cấu hình Fastlane để tự động hóa việc deploy cho cả Android và iOS lên Google Play Store, TestFlight và Firebase App Distribution.

```sh
finvoras_gen fastlane
```

**Các bước tự động thực hiện:**

1. Kiểm tra sự tồn tại của thư mục `android/` và `ios/`.
2. **Tự động sinh cấu hình**: Tự động tạo `Appfile` (sử dụng `app_id` từ dự án) và `Gemfile` mà không cần nhập liệu thủ công.
3. Tạo file `Fastfile` với các lane chuẩn cho cả 2 nền tảng:
   - `increment_version`: Tự động tăng build number trong `pubspec.yaml` (đồng bộ cho cả Android/iOS).
   - `deploy`: Build và Upload lên Play Store (`internal`) hoặc TestFlight.
   - `production`: Build và Upload lên Play Store (`production`) hoặc App Store.
   - `beta`: Build và Upload lên Firebase App Distribution.
4. **Tùy chọn nâng cao**: Sau khi setup cơ bản, bạn có thể chọn chạy `fastlane init` để thiết lập nâng cao (metadata, screenshots).

**Đặc điểm nổi bật:**

- **Auto Flow**: Tự động lấy `app_id` từ `pubspec.yaml` để cấu hình `Appfile`.
- **Đa nền tảng**: Hỗ trợ đầy đủ cho cả Android và iOS trong cùng một lệnh.
- **Hỗ trợ Flavor**: Tự động nhận diện nếu dự án có sử dụng flavors. Mặc định sẽ build flavor `prod`.
- **Release Notes**: Tự động tạo file changelog cho Android từ input của người dùng.

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
