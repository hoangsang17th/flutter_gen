import 'dart:io';
import 'base_command.dart';

class FastlaneCommand extends BaseCommand {
  @override
  final name = 'fastlane';

  @override
  final description =
      'Setup fastlane for Android and iOS using Fastlane CLI and pre-configured lanes.';

  @override
  Future<void> run() async {
    try {
      await _execute();
      print('\n✅ Fastlane setup completed successfully!');
    } catch (e) {
      print('\n💥 Fastlane setup failed!');
      print(e);
    }
  }

  Future<void> _execute() async {
    // 1. Pre-flight checks
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception(
          'pubspec.yaml not found. Please run this command in a Flutter project root.',);
    }

    // 2. Check if fastlane is installed
    try {
      await Process.run('fastlane', ['--version']);
    } catch (_) {
      print('⚠️ Fastlane is not installed or not in PATH.');
      print(
          '💡 Please install it first: https://docs.fastlane.tools/getting-started/ios/setup/',);
      return;
    }

    // 3. Setup Android
    if (Directory('android').existsSync()) {
      await _setupPlatform('android');
    }

    // 4. Setup iOS
    if (Directory('ios').existsSync()) {
      await _setupPlatform('ios');
    }
  }

  Future<void> _setupPlatform(String platform) async {
    print('\n🚀 Setting up Fastlane for $platform...');

    final appId = projectService.readPubspecConfig(['finvoras_gen', 'app_id'])
            as String? ??
        'com.example.app';
    final flavors =
        projectService.readPubspecConfig(['flavorizr', 'flavors']) as Map?;

    // 1. Ensure fastlane directory exists
    final fastlaneDir = Directory('$platform/fastlane');
    if (!fastlaneDir.existsSync()) {
      await fastlaneDir.create(recursive: true);
    }

    // 2. Create Appfile automatically
    final appfile = File('$platform/fastlane/Appfile');
    if (!appfile.existsSync()) {
      String appfileContent;
      if (platform == 'android') {
        appfileContent = '''json_key_file("play-store-secret.json")
package_name(ENV["APP_ID"] || "$appId")
''';
      } else {
        appfileContent = '''app_identifier(ENV["APP_ID"] || "$appId")
apple_id("apple@example.com") # TODO: Update your Apple ID
# itc_team_id("...")
# team_id("...")
''';
      }
      await appfile.writeAsString(appfileContent);
      print('📝 Created $platform/fastlane/Appfile');
    }

    // 3. Create/Update Gemfile if not exists
    final gemfile = File('$platform/Gemfile');
    if (!gemfile.existsSync()) {
      await gemfile.writeAsString(
          'source "https://rubygems.org"\n\ngem "fastlane"\n',);
      print('📝 Created $platform/Gemfile');
    }

    // 4. Write custom Fastfile
    if (platform == 'android') {
      await _writeAndroidFastfile(appId, flavors);
    } else {
      await _writeIosFastfile(appId, flavors);
    }

    // 5. Optional fastlane init (Interactive)
    print('\n💡 Basic Fastlane structure is ready.');
    stdout.write(
        '❓ Do you want to run "fastlane init" for advanced store setup (metadata, screenshots)? (y/N): ',);
    final input = stdin.readLineSync()?.toLowerCase();

    if (input == 'y') {
      print('📦 Starting fastlane init in $platform directory...');
      final process = await Process.start(
        'fastlane',
        ['init'],
        workingDirectory: platform,
        mode: ProcessStartMode.inheritStdio,
        runInShell: true,
      );
      await process.exitCode;
    }
  }

  Future<void> _writeAndroidFastfile(String defaultAppId, Map? flavors) async {
    final fastfile = File('android/fastlane/Fastfile');

    String flavorMapping = '';
    if (flavors != null) {
      flavorMapping = 'FLAVOR_IDS = {\n';
      flavors.forEach((key, value) {
        final id = value['android']?['applicationId'] ?? defaultAppId;
        flavorMapping += '    "$key" => "$id",\n';
      });
      flavorMapping += '  }';
    }

    final content = '''
default_platform(:android)

${flavorMapping.isNotEmpty ? flavorMapping : 'FLAVOR_IDS = {}'}

platform :android do
  desc "Tự động tăng build number trong pubspec.yaml"
  lane :increment_version do
    pubspec_path = "../../pubspec.yaml"
    content = File.read(pubspec_path)
    
    # Tìm dòng version: x.y.z+n
    if content =~ /version: (\\d+\\.\\d+\\.\\d+)\\+(\\d+)/
      version_name = \$1
      build_number = \$2.to_i + 1
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

  desc "Build và Deploy lên Google Play Store (Closed Testing - Alpha)"
  lane :closed do |options|
    deploy_to_play_store(track: "alpha", options: options)
  end

  desc "Build và Deploy lên Google Play Store (Production)"
  lane :production do |options|
    UI.important("⚠️ BẠN ĐANG CHUẨN BỊ DEPLOY LÊN PRODUCTION!")
    UI.confirm("Bạn có chắc chắn muốn tiếp tục không?")
    
    deploy_to_play_store(track: "production", options: options)
  end

  private_lane :deploy_to_play_store do |params|
    track = params[:track]
    options = params[:options]
    flavor = options[:flavor] || "prod"
    
    # Set App ID dynamically for Appfile
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "$defaultAppId"

    release_notes = options[:notes] || UI.input("Nhập Release Notes cho bản [#{track}]: ")

    changelog_dir = "metadata/android/vi/changelogs"
    FileUtils.rm_rf("metadata/android")
    FileUtils.mkdir_p(changelog_dir)
    File.write("#{changelog_dir}/default.txt", release_notes)

    increment_version

    use_flavor = File.directory?("../../android/app/src/#{flavor}")
    
    build_cmd = "cd ../.. && flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols"
    if use_flavor
      build_cmd += " --flavor #{flavor}"
      aab_path = "../build/app/outputs/bundle/#{flavor}Release/app-#{flavor}-release.aab"
    else
      aab_path = "../build/app/outputs/bundle/release/app-release.aab"
    end
    
    sh(build_cmd)
    
    upload_to_play_store(
      track: track,
      aab: aab_path,
      skip_upload_metadata: true,
      skip_upload_changelogs: false,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      skip_upload_apk: true
    )
    
    UI.success("✅ Đã deploy thành công lên [#{track}] với ghi chú: #{release_notes}")
  end

  lane :beta do |options|
    flavor = options[:flavor] || "prod"
    
    # Set App ID dynamically for Appfile
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "$defaultAppId"

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
    print('📝 Updated android/fastlane/Fastfile');
  }

  Future<void> _writeIosFastfile(String defaultAppId, Map? flavors) async {
    final fastfile = File('ios/fastlane/Fastfile');

    String flavorMapping = '';
    if (flavors != null) {
      flavorMapping = 'FLAVOR_IDS = {\n';
      flavors.forEach((key, value) {
        final id = value['ios']?['bundleId'] ?? defaultAppId;
        flavorMapping += '    "$key" => "$id",\n';
      });
      flavorMapping += '  }';
    }

    final content = '''
default_platform(:ios)

${flavorMapping.isNotEmpty ? flavorMapping : 'FLAVOR_IDS = {}'}

platform :ios do
  desc "Tự động tăng build number trong pubspec.yaml"
  lane :increment_version do
    pubspec_path = "../../pubspec.yaml"
    content = File.read(pubspec_path)
    
    if content =~ /version: (\\d+\\.\\d+\\.\\d+)\\+(\\d+)/
      version_name = \$1
      build_number = \$2.to_i + 1
      new_version = "#{version_name}+#{build_number}"
      
      new_content = content.sub(/version: .*/, "version: #{new_version}")
      File.open(pubspec_path, "w") { |file| file.puts new_content }
      
      UI.success("🚀 Đã cập nhật version lên: #{new_version}")
    else
      UI.user_error!("Không tìm thấy định dạng version trong pubspec.yaml")
    end
  end

  desc "Build và Deploy lên TestFlight"
  lane :deploy do |options|
    deploy_to_testflight(options: options)
  end

  desc "Build và Deploy lên App Store"
  lane :production do |options|
    UI.important("⚠️ BẠN ĐANG CHUẨN BỊ DEPLOY LÊN PRODUCTION (App Store)!")
    UI.confirm("Bạn có chắc chắn muốn tiếp tục không?")
    
    # Set App ID dynamically for Appfile
    flavor = options[:flavor] || "prod"
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "$defaultAppId"

    deploy_to_app_store(
      force: true,
      submit_for_review: false,
      skip_metadata: true,
      skip_screenshots: true
    )
  end

  private_lane :deploy_to_testflight do |params|
    options = params[:options]
    flavor = options[:flavor] || "prod"
    
    # Set App ID dynamically for Appfile
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "$defaultAppId"

    increment_version

    build_cmd = "cd ../.. && flutter build ipa --release --obfuscate --split-debug-info=build/ios/outputs/symbols"
    if flavor != "prod"
      build_cmd += " --flavor #{flavor}"
    end
    
    sh(build_cmd)
    
    upload_to_testflight(
      ipa: "../build/ios/ipa/Runner.ipa",
      skip_waiting_for_build_processing: true
    )
    
    UI.success("✅ Đã deploy thành công lên TestFlight")
  end

  lane :beta do |options|
    flavor = options[:flavor] || "prod"
    
    # Set App ID dynamically for Appfile
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "$defaultAppId"

    build_cmd = "cd ../.. && flutter build ios --release --no-codesign --obfuscate --split-debug-info=build/ios/outputs/symbols"
    if flavor != "prod"
      build_cmd += " --flavor #{flavor}"
    end
    sh(build_cmd)
    
    firebase_app_distribution(
      app: ENV["FIREBASE_APP_ID_IOS"],
      groups: "testers",
      release_notes: "Bản build iOS tự động"
    )
  end
end
''';
    await fastfile.writeAsString(content);
    print('📝 Updated ios/fastlane/Fastfile');
  }
}
