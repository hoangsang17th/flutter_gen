import 'dart:io';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';
import 'base_command.dart';

class InitCommand extends BaseCommand {
  @override
  final name = 'init';

  @override
  final description =
      'Initialize a new Flutter project with core packages and submodules.';

  @override
  Future<void> run() async {
    try {
      await _execute();
    } catch (e) {
      print('\n💥 Initialization failed!');
      print(e);
      print('\n💡 Please check the errors above and try again.');
    }
  }

  Future<void> _execute() async {
    // 1. Check arguments
    if (argResults?.rest.isEmpty ?? true) {
      print('❌ Error: Please provide an application ID (e.g., com.example.app)');
      return;
    }

    final appId = argResults!.rest.first;
    final parts = appId.split('.');
    if (parts.length < 2) {
      print(
        '❌ Error: Invalid application ID. It should be in the format com.example.app',
      );
      return;
    }

    final appName = parts.last;
    final org = parts.sublist(0, parts.length - 1).join('.');

    // 2. Pre-flight checks
    final packagesDir = Directory('packages');
    if (packagesDir.existsSync()) {
      print('⚠️  Warning: "packages" directory already exists.');
      stdout.write('👉 Do you want to continue? (y/n): ');
      final input = stdin.readLineSync();
      if (input?.toLowerCase() != 'y') {
        print('⏭️  Initialization aborted.');
        return;
      }
    }

    print('🚀 Initializing project $appName ($appId)...');

    // 3. Create new app
    await runCommand('flutter', [
      'create',
      '--org',
      org,
      '--project-name',
      appName,
      '.',
    ]);

    // 4. Clone submodule
    print('\n📦 Cloning packages submodule...');
    if (packagesDir.existsSync()) {
      print('⚠️  "packages" directory already exists. Skipping clone.');
    } else {
      try {
        await runCommand('git', [
          'clone',
          '--recurse-submodules',
          'https://github.com/hoangsang17th/packages',
          'packages',
        ]);
      } catch (e) {
        print('❌ Failed to clone submodule.');
        print('👉 This might be due to network issues or missing permissions.');
        print('👉 You can try cloning it manually later:');
        print(
            '   git clone --recurse-submodules https://github.com/hoangsang17th/packages packages');
        rethrow;
      }
    }

    // 5. Link submodule packages
    await _linkSubmodulePackages();

    // 6. Setup Melos
    await _setupMelosConfig(appName);

    // 7. Setup Pubspec (Core packages and finvoras_gen)
    await _setupPubspecConfigs(appId);

    // 8. Setup iOS Podfile
    await _setupIosPodfile();

    // 9. Run pub get
    await runCommand('flutter', ['pub', 'get']);

    print('\n✅ Project initialized successfully!');
    print('💡 Next step: Run "finvoras_gen branding" to setup flavors and icons.');
  }

  Future<void> _setupPubspecConfigs(String appId) async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception(
          '❌ "pubspec.yaml" not found. "flutter create" might have failed silently.');
    }

    // Add common packages
    await runCommand('flutter', [
      'pub',
      'add',
      'injectable',
      'get_it',
      'equatable',
      'dev:build_runner',
      'dev:json_serializable',
      'dev:injectable_generator',
    ]);

    // NOW read the updated content
    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);

    // Helper to safely check and add config if missing
    void ensureConfig(List<String> path, dynamic value) {
      try {
        editor.parseAt(path);
      } catch (e) {
        editor.update(path, value);
      }
    }

    ensureConfig(['finvoras_gen'], {
      'app_id': appId,
      'output': 'lib/generated/',
      'line_length': 80,
      'assets': {
        'enabled': true,
        'outputs': {
          'class_name': 'AppAssets',
          'package_parameter_enabled': false,
        },
      },
      'locales': {
        'enabled': true,
        'folder': 'assets/locales',
        'outputs': {
          'translation_name': 'AppTranslation',
          'keys_name': 'AppLocalesKeys',
        },
      },
      'integrations': {
        'flutter_svg': true,
        'lottie': true,
      },
    });

    await pubspecFile.writeAsString(editor.toString());

    // Create placeholder directories
    await Directory('assets/images').create(recursive: true);
    await Directory('assets/locales').create(recursive: true);
    print('Created assets/images and assets/locales directories');
  }

  Future<void> _setupMelosConfig(String appName) async {
    final melosFile = File('melos.yaml');
    final content = '''
name: $appName
packages:
  - .
  - packages/**
''';
    await melosFile.writeAsString(content);
    print('Created melos.yaml');
  }

  Future<void> _linkSubmodulePackages() async {
    final packagesDir = Directory('packages');
    if (!await packagesDir.exists()) {
      throw Exception(
          '❌ "packages" directory not found. "git clone" might have failed.');
    }

    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception('❌ "pubspec.yaml" not found.');
    }

    final List<String> localPackages = [];
    await for (final entity in packagesDir.list()) {
      if (entity is Directory) {
        final subPubspec = File('${entity.path}/pubspec.yaml');
        if (await subPubspec.exists()) {
          final name = entity.path.split(Platform.pathSeparator).last;
          localPackages.add(name);
        }
      }
    }

    if (localPackages.isEmpty) return;

    print('🔗 Linking local packages: ${localPackages.join(', ')}...');
    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);

    for (final pkg in localPackages) {
      editor.update(['dependencies', pkg], {
        'path': 'packages/$pkg',
      });
    }

    // Add Dart Workspace configuration
    try {
      final editorContent = editor.parseAt(['workspace']);
      final List workspaceList =
          editorContent is YamlList ? editorContent.value.toList() : [];

      for (final pkg in localPackages) {
        final path = 'packages/$pkg';
        if (!workspaceList.contains(path)) {
          workspaceList.add(path);
        }
      }
      editor.update(['workspace'], workspaceList);
    } catch (e) {
      editor.update(
          ['workspace'], localPackages.map((pkg) => 'packages/$pkg').toList());
    }

    await pubspecFile.writeAsString(editor.toString());
  }

  Future<void> _setupIosPodfile() async {
    final podfile = File('ios/Podfile');
    if (!await podfile.exists()) {
      return;
    }

    print('📱 Setting iOS platform to 15.0 in Podfile...');
    final content = await podfile.readAsString();

    // Regex to find and replace platform :ios, '...'
    // It might be commented out like # platform :ios, '9.0'
    final platformRegex = RegExp(
        r'''^\s*#?\s*platform\s+:ios,\s+['"][^'"]+['"]''',
        multiLine: true);

    if (platformRegex.hasMatch(content)) {
      final newContent =
          content.replaceFirst(platformRegex, "platform :ios, '15.0'");
      await podfile.writeAsString(newContent);
      print('✅ Updated ios/Podfile platform to 15.0');
    } else {
      // If not found, prepend it
      final newContent = "platform :ios, '15.0'\n$content";
      await podfile.writeAsString(newContent);
      print('✅ Added platform :ios, 15.0 to ios/Podfile');
    }
  }
}
