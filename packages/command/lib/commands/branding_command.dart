import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'base_command.dart';

class BrandingCommand extends BaseCommand {
  BrandingCommand() {
    argParser.addOption(
      'type',
      abbr: 't',
      help:
          'Flavor type: behavior (single application ID) or platform (multiple application IDs per flavor)',
      defaultsTo: 'behavior',
      allowed: ['behavior', 'platform'],
    );
    argParser.addOption(
      'envs',
      abbr: 'e',
      help: 'Comma-separated list of environments (flavors)',
      defaultsTo: 'dev,qa,prod',
    );
  }

  @override
  final name = 'branding';

  @override
  final description =
      'Setup flavors (behavior or platform ID-based), native splash screen, and launcher icons.';

  @override
  Future<void> run() async {
    try {
      await _execute();
    } catch (e) {
      print('\n💥 Branding setup failed!');
      print(e);
      print('\n💡 Please check the errors above and try again.');
    }
  }

  List<String> get _environments {
    final envs = argResults?['envs'] as String? ?? 'dev,qa,prod';
    return envs
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _execute() async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception(
        '❌ "pubspec.yaml" not found. Please run this command in a Flutter project root.',
      );
    }

    final pubspecContent = await pubspecFile.readAsString();
    final doc = loadYaml(pubspecContent);
    final appName = doc['name'] as String;
    final String appId = doc['finvoras_gen']?['app_id'] ?? 'com.example.app';

    final type = argResults?['type'] as String;

    print('🚀 Setting up branding for $appName...');
    print(
      '📍 Mode: ${type == 'behavior' ? 'Application Behavior (Single ID)' : 'Platform ID + Behavior (Multiple IDs)'}',
    );

    // 1. Setup Configuration
    print('🛠 Generating flavorizr and branding configurations...');
    await _setupFlavorizrConfig(appName, appId, type);
    await _setupBrandingConfigs();

    // 2. Add Dependencies
    print('\n📦 Adding branding dependencies...');
    await runCommand('flutter', [
      'pub',
      'add',
      'dev:flutter_flavorizr',
      'dev:flutter_native_splash',
      'dev:flutter_launcher_icons',
    ]);

    // 3. Generate Assets (Splash/Icons)
    await _runGenCommands();

    print('\n✅ Branding configuration setup successfully!');
    print('\n🚀 TO FINISH SETUP, RUN:');
    print('   flutter pub run flutter_flavorizr');
    print('\n💡 This will automatically:');
    print('   - Create native flavors/schemes in Android/iOS');
    print('   - Update Application IDs / Bundle IDs');
    print('   - Generate "lib/flavors.dart" and "lib/main-<flavor>.dart"');
    print(
      '   - Generate VSCode launch configurations in ".vscode/launch.json"',
    );
    print(
      '\n⚠️  Note: Make sure you have Ruby and Xcodeproj installed for iOS support.',
    );
  }

  Future<void> _setupFlavorizrConfig(
    String appName,
    String appId,
    String type,
  ) async {
    final pubspecFile = File('pubspec.yaml');
    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);

    final behaviors = _environments;
    final Map<String, dynamic> flavors = {};

    for (final behavior in behaviors) {
      String currentAppId = appId;
      if (type == 'platform' && behavior != 'prod') {
        currentAppId = '$appId.$behavior';
      }

      flavors[behavior] = {
        'app': {'name': '$appName ${behavior.toUpperCase()}'},
        'android': {
          'applicationId': currentAppId,
          'generateDummyAssets': false,
        },
        'ios': {
          'bundleId': currentAppId,
          'generateDummyAssets': false,
        },
      };
    }

    editor.update(['flavorizr'], {
      'ide': 'vscode',
      'flavors': flavors,
    });

    await pubspecFile.writeAsString(editor.toString());
    print('Updated flavorizr configuration in pubspec.yaml');
  }

  Future<void> _setupBrandingConfigs() async {
    final behaviors = _environments;
    final logoPath = 'assets/images/logo.png';

    for (final behavior in behaviors) {
      // 1. Splash Screen Config
      final splashFile = File('flutter_native_splash-$behavior.yaml');
      final splashContent = '''
flutter_native_splash:
  color: "#ffffff"
  image: $logoPath
  fullscreen: true
  
  android_12:
    color: "#ffffff"
    image: $logoPath
    icon_background_color: "#ffffff"
''';
      await splashFile.writeAsString(splashContent);
      print('Created ${splashFile.path}');

      // 2. Launcher Icons Config
      final iconFile = File('flutter_launcher_icons-$behavior.yaml');
      final iconContent = '''
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  web:
    generate: true
    image_path: "$logoPath"
    background_color: "#ffffff"
    theme_color: "#ffffff"
  windows:
    generate: true
    image_path: "$logoPath"
  macos:
    generate: true
    image_path: "$logoPath"
  image_path: "$logoPath"
  
  # iOS 18+ support
  image_path_ios_dark_transparent: "$logoPath"
  image_path_ios_tinted_grayscale: "$logoPath"
  desaturate_tinted_to_grayscale_ios: true
''';
      await iconFile.writeAsString(iconContent);
      print('Created ${iconFile.path}');
    }

    print('Branding configuration files created for all flavors.');
  }

  Future<void> _runGenCommands() async {
    final logoPath = 'assets/images/logo.png';

    if (!File(logoPath).existsSync()) {
      print('\n⚠️  Logo image not found at $logoPath');
      print('👉 Please add your logo file to the "assets/images/" directory.');
      stdout.write(
        '⌨️  Press [Enter] to run generation, or [s] to skip this step: ',
      );

      final input = stdin.readLineSync();
      if (input?.toLowerCase() == 's') {
        print('⏭️  Skipping splash and icon generation.');
        return;
      }

      if (!File(logoPath).existsSync()) {
        print('❌ File still missing. Skipping generation to avoid errors.');
        print('💡 You can run it later with:');
        print('   dart run flutter_native_splash:create --all-flavors');
        print(
          '   dart run flutter_launcher_icons -f flutter_launcher_icons-<flavor>.yaml',
        );
        return;
      }
    }

    print('🎨 Generating resources...');

    // 1. Run Flavorizr first to create native structures
    print('🔨 Running flutter_flavorizr...');
    await runCommand('dart', ['run', 'flutter_flavorizr', '-f']);

    // 2. Run Splash (supports flavors from pubspec.yaml)
    print('💦 Generating splash screens...');
    await runCommand('dart',
        ['run', 'flutter_native_splash:create', '--all-flavors']);

    // 3. Run Icons (supports flavors from pubspec.yaml)
    print('📦 Generating launcher icons...');
    await runCommand('dart', ['run', 'flutter_launcher_icons']);
  }
}
