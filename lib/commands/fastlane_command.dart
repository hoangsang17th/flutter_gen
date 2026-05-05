import 'dart:io';

import 'base_command.dart';

class FastlaneCommand extends BaseCommand {
  @override
  final name = 'fastlane';

  @override
  final description = 'Setup fastlane for deployment with pre-configured lanes.';

  @override
  Future<void> run() async {
    try {
      await _execute();
      print('\n✅ Fastlane setup successfully!');
    } catch (e) {
      print('\n💥 Fastlane setup failed!');
      print(e);
    }
  }

  Future<void> _execute() async {
    // 1. Pre-flight checks
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found. Please run this command in a Flutter project root.');
    }

    print('🚀 Setting up fastlane...');

    // 2. Setup Android Fastlane
    await _setupAndroidFastlane();
  }

  Future<void> _setupAndroidFastlane() async {
    final androidFastlaneDir = Directory('android/fastlane');
    if (!androidFastlaneDir.existsSync()) {
      await androidFastlaneDir.create(recursive: true);
      print('📁 Created directory: android/fastlane');
    }

    final fastfile = File('android/fastlane/Fastfile');
    
    final content = r'''
default_platform(:android)

platform :android do
  desc "Tự động tăng build number trong pubspec.yaml"
  lane :increment_version do
    pubspec_path = "../../pubspec.yaml"
    content = File.read(pubspec_path)
    
    # Tìm dòng version: x.y.z+n
    if content =~ /version: (\d+\.\d+\.\d+)\+(\d+)/
      version_name = $1
      build_number = $2.to_i + 1
      new_version = "#{version_name}+#{build_number}"
      
      # Ghi lại vào file
      new_content = content.sub(/version: .*/, "version: #{new_version}")
      File.open(pubspec_path, "w") { |file| file.puts new_content }
      
      UI.success("🚀 Đã cập nhật version lên: #{new_version}")
    else
      UI.user_error!("Không tìm thấy định dạng version trong pubspec.yaml")
    end
  end

  desc "Build và Deploy lên Google Play Store (Internal Track)"
  lane :deploy do |options|
    deploy_to_play_store(track: "internal", options: options)
  end

  desc "Build và Deploy lên Google Play Store (Internal Track)"
  lane :deploy do |options|
    deploy_to_play_store(track: "internal", options: options)
  end

  desc "Build và Deploy lên Google Play Store (Closed Testing - Alpha)"
  lane :closed do |options|
    deploy_to_play_store(track: "alpha", options: options)
  end

  desc "Build và Deploy lên Google Play Store (Production)"
  lane :production do |options|
    # Đối với production, có thể bạn muốn hỏi xác nhận lại một lần nữa
    UI.important("⚠️ BẠN ĐANG CHUẨN BỊ DEPLOY LÊN PRODUCTION!")
    UI.confirm("Bạn có chắc chắn muốn tiếp tục không?")
    
    deploy_to_play_store(track: "production", options: options)
  end

  # Hàm dùng chung để tránh lặp code
  private_lane :deploy_to_play_store do |params|
    track = params[:track]
    options = params[:options]
    flavor = options[:flavor] || "prod" # Mặc định dùng prod flavor nếu có branding

    # 1. Hỏi nhập Release Notes
    release_notes = options[:notes] || UI.input("Nhập Release Notes cho bản [#{track}]: ")

    # 2. Tạo file changelog với locale chuẩn vi-VN (BCP 47 theo yêu cầu Play Store)
    changelog_dir = "metadata/android/vi/changelogs"
    FileUtils.rm_rf("metadata/android")
    FileUtils.mkdir_p(changelog_dir)
    File.write("#{changelog_dir}/default.txt", release_notes)

    # 3. Tăng version
    increment_version

    # 4. Kiểm tra xem có sử dụng flavor không (dựa trên sự tồn tại của thư mục flavor trong android/app/src)
    use_flavor = File.directory?("../../android/app/src/#{flavor}")
    
    # 5. Chạy flutter build với obfuscate
    build_cmd = "cd ../.. && flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols"
    if use_flavor
      build_cmd += " --flavor #{flavor}"
      aab_path = "../build/app/outputs/bundle/#{flavor}Release/app-#{flavor}-release.aab"
    else
      aab_path = "../build/app/outputs/bundle/release/app-release.aab"
    end
    
    sh(build_cmd)
    
    # 6. Upload lên Play Store
    upload_to_play_store(
      track: track,
      aab: aab_path,
      skip_upload_metadata: true,        # Không sync store listing
      skip_upload_changelogs: false,     # Chỉ upload changelog vừa tạo
      skip_upload_images: true,
      skip_upload_screenshots: true,
      skip_upload_apk: true
    )
    
    UI.success("✅ Đã deploy thành công lên [#{track}] với ghi chú: #{release_notes}")
  end

  # Giữ lại lane beta nếu cần đẩy lên Firebase
  lane :beta do |options|
    flavor = options[:flavor] || "prod"
    use_flavor = File.directory?("../../android/app/src/#{flavor}")
    
    build_cmd = "cd ../.. && flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols"
    if use_flavor
      build_cmd += " --flavor #{flavor}"
      apk_path = "../build/app/outputs/flutter-apk/app-#{flavor}-release.apk"
    else
      apk_path = "../build/app/outputs/flutter-apk/app-release.apk"
    end

    sh(build_cmd)
    
    firebase_app_distribution(
      app: ENV["FIREBASE_APP_ID_ANDROID"],
      groups: "testers",
      release_notes: "Bản build obfuscated tự động",
      apk_path: apk_path
    )
  end
end
''';

    await fastfile.writeAsString(content);
    print('📝 Created android/fastlane/Fastfile');
  }
}
