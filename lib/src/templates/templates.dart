class Templates {
  static const splashYaml = r'''
flutter_native_splash:
  color: "{{color}}"
  image: {{logoPath}}
  fullscreen: true

  android_12:
    color: "{{color}}"
    image: {{logoPath}}
    icon_background_color: "{{color}}"
''';

  static const launcherIconsYaml = r'''
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "{{logoPath}}"
''';

  static const mainDart = r'''
import 'package:flutter/material.dart';
{{#isBloc}}import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';{{/isBloc}}{{#isGetX}}import 'package:get/get.dart';{{/isGetX}}
import 'core/config/prepare.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  await prepareApp(binding);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppOrchestrator(
      child: {{#isBloc}}MaterialApp.router(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ){{/isBloc}}{{#isGetX}}GetMaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(child: Text('App Prepared with GetX!')),
        ),
      ){{/isGetX}},
    );
  }
}

{{#isBloc}}
final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('App Prepared with Bloc & GoRouter!')),
      ),
    ),
  ],
);
{{/isBloc}}

class AppOrchestrator extends StatelessWidget {
  final Widget child;
  const AppOrchestrator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // AppOrchestrator wraps the main app to provide global providers or configurations
    // For example, MultiBlocProvider for Bloc or initial bindings for GetX
    return child;
  }
}
''';

  static const prepareDart = r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
// TODO: Import your services and DI here
// import '../../src/di/injection.dart';

Future<void> prepareApp(WidgetsBinding binding) async {
  // 1. Error widget builder
  ErrorWidget.builder = (_) => const SizedBox.shrink();

  // 2. Preserve splash screen
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // 3. System UI Mode
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
  );

  // 4. Dependency Injection
  // await configureDependencies();
  // registerAppOrchestratorDependencies();

  // 5. Core Services Initialization
  // await AppPathService.instance.init();
  // await AppKeyStorage.instance.init();
  // await AppActions.instance.init();

  // 6. Preferred Orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 7. Remove splash screen
  FlutterNativeSplash.remove();
}
''';

  static const androidFastfile = r'''
default_platform(:android)

{{#hasFlavors}}
FLAVOR_IDS = {
{{#flavors}}
    "{{name}}" => "{{appId}}",
{{/flavors}}
  }
{{/hasFlavors}}
{{^hasFlavors}}
FLAVOR_IDS = {}
{{/hasFlavors}}

platform :android do
  desc "Tự động tăng build number trong pubspec.yaml"
  lane :increment_version do
    pubspec_path = "../../pubspec.yaml"
    content = File.read(pubspec_path)

    # Tìm dòng version: x.y.z+n hoặc x.y.z
    if content =~ /version: (\d+\.\d+\.\d+)(?:\+(\d+))?/
      version_name = $1
      build_number = ($2 || "0").to_i + 1
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
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "{{defaultAppId}}"

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
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "{{defaultAppId}}"

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

  static const iosFastfile = r'''
default_platform(:ios)

{{#hasFlavors}}
FLAVOR_IDS = {
{{#flavors}}
    "{{name}}" => "{{appId}}",
{{/flavors}}
  }
{{/hasFlavors}}
{{^hasFlavors}}
FLAVOR_IDS = {}
{{/hasFlavors}}

platform :ios do
  desc "Tự động tăng build number trong pubspec.yaml"
  lane :increment_version do
    pubspec_path = "../../pubspec.yaml"
    content = File.read(pubspec_path)

    if content =~ /version: (\d+\.\d+\.\d+)(?:\+(\d+))?/
      version_name = $1
      build_number = ($2 || "0").to_i + 1
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
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "{{defaultAppId}}"

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
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "{{defaultAppId}}"

    increment_version

    build_cmd = "cd ../.. && flutter build ipa --release --obfuscate --split-debug-info=build/ios/outputs/symbols"
    if flavor != "prod"
      build_cmd += " --flavor #{flavor}"
    end

    sh(build_cmd)

    upload_to_testflight(
      ipa: "../../build/ios/ipa/Runner.ipa",
      skip_waiting_for_build_processing: true
    )

    UI.success("✅ Đã deploy thành công lên TestFlight")
  end

  lane :beta do |options|
    flavor = options[:flavor] || "prod"

    # Set App ID dynamically for Appfile
    ENV["APP_ID"] = FLAVOR_IDS[flavor] || "{{defaultAppId}}"

    build_cmd = "cd ../.. && flutter build ipa --release --no-codesign --obfuscate --split-debug-info=build/ios/outputs/symbols"
    if flavor != "prod"
      build_cmd += " --flavor #{flavor}"
    end
    sh(build_cmd)

    firebase_app_distribution(
      app: ENV["FIREBASE_APP_ID_IOS"],
      groups: "testers",
      release_notes: "Bản build iOS tự động",
      ipa_path: "../../build/ios/ipa/Runner.ipa"
    )
  end
end
''';
}
