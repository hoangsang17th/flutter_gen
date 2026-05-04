# FinvorasGen 🚀

Công cụ hỗ trợ phát triển Flutter nội bộ: Generator Assets & Project Bootstrapper.

## 🛠 Cài đặt

Vì đây là công cụ nội bộ, bạn nên cài đặt trực tiếp từ source hoặc thông qua path:

```sh
# Cài đặt toàn cục (Global)
dart pub global activate --source path packages/command
```

## 🚀 Sử dụng

### 1. Khởi tạo dự án mới (`init`)

Sử dụng khi bạn bắt đầu một dự án Flutter mới để tự động hóa toàn bộ cấu hình chuẩn.

```sh
finvoras_gen init <app-id>
```

**Các bước thực hiện:**

- Khởi tạo Flutter App & cấu hình Flavors (dev, qa, prod).
- Thiết lập VSCode Debugger.
- Cài đặt bộ package chuẩn: `injectable`, `get_it`, `equatable`,...
- Cấu hình Splash Screen & Launcher Icons.
- Clone & Link submodule `packages` nội bộ.
- Khởi tạo Melos monorepo.

### 2. Gen Assets (`assets`)

Sử dụng hàng ngày để tạo các class Assets type-safe.

```sh
# Mặc định (sử dụng pubspec.yaml)
finvoras_gen assets

### 3. Setup Branding (`branding`)

Thiết lập flavors, native splash screen và launcher icons cho dự án.

```sh
# Mặc định (dev, qa, prod)
finvoras_gen branding

# Tùy chỉnh danh sách environments
finvoras_gen branding --envs dev,staging,prod

# Sử dụng chế độ platform (mỗi flavor một Application ID riêng)
finvoras_gen branding --type platform --envs dev,stg,prod
```

**Các tùy chọn:**

- `--envs`, `-e`: Danh sách các môi trường (flavors), phân cách bằng dấu phẩy. Mặc định: `dev,qa,prod`.
- `--type`, `-t`: Chế độ flavor:
  - `behavior`: Sử dụng chung một Application ID (mặc định).
  - `platform`: Mỗi flavor một Application ID riêng (ví dụ: `.dev`, `.qa`).

### 4. Refresh Project (`refresh`)

Sử dụng khi bạn cần dọn dẹp và lấy lại dependencies (rất hữu ích khi vừa đổi branch hoặc bị lỗi cache).

```sh
finvoras_gen refresh
```

**Các bước thực hiện:**

- Chạy `flutter clean` để dọn dẹp build cache.
- Chạy `flutter pub get` để lấy lại toàn bộ dependencies.

## 📝 Cấu hình `pubspec.yaml`

Thêm cấu hình sau vào `pubspec.yaml` để tùy chỉnh việc gen:

```yaml
finvoras_gen:
  output: lib/gen/ # Thư mục xuất file
  line_length: 80
  integrations:
    image: true
    flutter_svg: true
    rive: true
    lottie: true

flutter:
  assets:
    - assets/images/
  fonts:
    - family: MyFont
      fonts:
        - asset: assets/fonts/MyFont-Regular.ttf
```

## 🔗 Submodule Packages

Lệnh `init` sẽ mặc định clone repository packages tại:
`https://github.com/hoangsang17th/packages` vào thư mục `packages/`.


# Try to verify

```bash
cd example
finvoras_gen init vn.io.enth17.chopchop
finvoras_gen branding
```