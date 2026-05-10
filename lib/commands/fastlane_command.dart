import 'dart:io';
import 'package:finvoras_gen/src/templates/templates.dart';
import 'package:finvoras_gen/src/utils/template_helper.dart';
import 'base_command.dart';

class FastlaneCommand extends BaseCommand {
  @override
  final name = 'fastlane';

  @override
  final description = 'Setup fastlane for Android and iOS using Fastlane CLI and pre-configured lanes.';

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
      throw Exception('pubspec.yaml not found. Please run this command in a Flutter project root.');
    }

    // 2. Check if fastlane is installed
    try {
      await Process.run('fastlane', ['--version']);
    } catch (_) {
      print('⚠️ Fastlane is not installed or not in PATH.');
      print('💡 Please install it first: https://docs.fastlane.tools/getting-started/ios/setup/');
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

    final appId = projectService.readPubspecConfig(['finvoras_gen', 'app_id']) as String? ?? 'com.example.app';
    final flavors = projectService.readPubspecConfig(['flavorizr', 'flavors']) as Map?;

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
      await gemfile.writeAsString("source \"https://rubygems.org\"\n\ngem \"fastlane\"\n");
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
    stdout.write('❓ Do you want to run "fastlane init" for advanced store setup (metadata, screenshots)? (y/N): ');
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
    
    final List<Map<String, String>> flavorList = [];
    if (flavors != null) {
      flavors.forEach((key, value) {
        final id = value['android']?['applicationId'] ?? defaultAppId;
        flavorList.add({'name': key.toString(), 'appId': id.toString()});
      });
    }

    final content = TemplateHelper.render(Templates.androidFastfile, {
      'hasFlavors': flavorList.isNotEmpty,
      'flavors': flavorList,
      'defaultAppId': defaultAppId,
    });

    await fastfile.writeAsString(content);
    print('📝 Updated android/fastlane/Fastfile');
  }

  Future<void> _writeIosFastfile(String defaultAppId, Map? flavors) async {
    final fastfile = File('ios/fastlane/Fastfile');
    
    final List<Map<String, String>> flavorList = [];
    if (flavors != null) {
      flavors.forEach((key, value) {
        final id = value['ios']?['bundleId'] ?? defaultAppId;
        flavorList.add({'name': key.toString(), 'appId': id.toString()});
      });
    }

    final content = TemplateHelper.render(Templates.iosFastfile, {
      'hasFlavors': flavorList.isNotEmpty,
      'flavors': flavorList,
      'defaultAppId': defaultAppId,
    });

    await fastfile.writeAsString(content);
    print('📝 Updated ios/fastlane/Fastfile');
  }
}
