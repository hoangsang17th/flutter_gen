import 'dart:io';
import 'package:args/command_runner.dart';

class InitCommand extends Command {
  @override
  final name = 'init';

  @override
  final description = 'Initialize a new Flutter project with flavors, vscode configs, and assets.';

  InitCommand() {
    // Positional argument: app-id
  }

  @override
  void run() async {
    if (argResults?.rest.isEmpty ?? true) {
      print('Please provide an application ID (e.g., com.example.app)');
      return;
    }

    final appId = argResults!.rest.first;
    final parts = appId.split('.');
    if (parts.length < 2) {
      print('Invalid application ID. It should be in the format com.example.app');
      return;
    }

    final appName = parts.last;
    final org = parts.sublist(0, parts.length - 1).join('.');

    print('🚀 Initializing project $appName ($appId)...');

    // 1. Create new app
    await _runCommand('flutter', [
      'create',
      '--org',
      org,
      '--project-name',
      appName,
      '.',
    ]);

    // 2. Setup Flavors (Basic setup)
    print('🛠 Setting up flavors (dev, qa, prod)...');
    await _createFlavorMainFiles(appName);

    // 3. Setup VSCode Launcher

    await _setupVSCodeLauncher(appName);

    // 4. Add configs for splash and icons
    await _setupPubspecConfigs();

    // 5. Run pub get
    await _runCommand('flutter', ['pub', 'get']);

    // 6. Run splash and icon gen
    print('\n🎨 Preparing splash screen and launcher icons...');
    await _runCommand('flutter', [
      'pub',
      'add',
      'dev:flutter_native_splash',
      'dev:flutter_launcher_icons'
    ]);

    final splashPath = 'assets/images/splash.png';
    final iconPath = 'assets/images/icon.png';

    bool hasAssets = File(splashPath).existsSync() && File(iconPath).existsSync();

    if (!hasAssets) {
      print('\n⚠️  Logo images not found at $splashPath or $iconPath');
      print('👉 Please add your logo files to the "assets/images/" directory.');
      stdout.write('⌨️  Press [Enter] to run generation, or [s] to skip this step: ');
      
      final input = stdin.readLineSync();
      if (input?.toLowerCase() == 's') {
        print('⏭️  Skipping splash and icon generation.');
      } else {
        // Re-check
        if (File(splashPath).existsSync() && File(iconPath).existsSync()) {
          await _runGenCommands();
        } else {
          print('❌ Files still missing. Skipping generation to avoid errors.');
          print('💡 You can run it later with:');
          print('   dart run flutter_native_splash:create');
          print('   dart run flutter_launcher_icons');
        }
      }
    } else {
      await _runGenCommands();
    }

    // 7. Clone submodule
    print('\n📦 Cloning packages submodule...');
    await _runCommand('git', [
      'clone',
      '--recurse-submodules',
      'https://github.com/hoangsang17th/packages',
      'packages'
    ]);

    // 8. Link submodule packages
    await _linkSubmodulePackages();

    // 9. Setup Melos
    await _setupMelosConfig(appName);

    print('✅ Project initialized successfully!');
  }

  Future<void> _runCommand(String command, List<String> arguments) async {
    print('Executing: $command ${arguments.join(' ')}');
    final result = await Process.run(command, arguments);
    if (result.exitCode != 0) {
      print('Error executing $command: ${result.stderr}');
    } else {
      print(result.stdout);
    }
  }

  Future<void> _createFlavorMainFiles(String appName) async {
    final libDir = Directory('lib');
    if (!await libDir.exists()) return;

    final flavors = ['dev', 'qa', 'prod'];
    for (final flavor in flavors) {
      final file = File('lib/main_$flavor.dart');
      final content = '''
import 'package:flutter/material.dart';
import 'main.dart' as app;

void main() {
  // TODO: Add $flavor specific configuration here
  app.main();
}
''';
      await file.writeAsString(content);
      print('Created lib/main_$flavor.dart');
    }
  }

  Future<void> _setupVSCodeLauncher(String appName) async {

    final vscodeDir = Directory('.vscode');
    if (!await vscodeDir.exists()) {
      await vscodeDir.create();
    }

    final launchJson = File('.vscode/launch.json');
    const content = r'''
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "App (dev)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--flavor", "dev", "--target", "lib/main_dev.dart"]
    },
    {
      "name": "App (qa)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--flavor", "qa", "--target", "lib/main_qa.dart"]
    },
    {
      "name": "App (prod)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--flavor", "prod", "--target", "lib/main_prod.dart"]
    }
  ]
}
''';
    await launchJson.writeAsString(content);
    print('Created .vscode/launch.json');
  }

  Future<void> _setupPubspecConfigs() async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) return;

    var content = await pubspecFile.readAsString();

    // Add common packages
    await _runCommand('flutter', [
      'pub',
      'add',
      'injectable',
      'get_it',
      'equatable',
      'dev:build_runner',
      'dev:json_serializable',
      'dev:injectable_generator'
    ]);

    // Append splash, icon and finvoras_gen configs if they don't exist
    if (!content.contains('flutter_native_splash:')) {
      content += '''
\nflutter_native_splash:
  color: "#ffffff"
  image: assets/images/splash.png
  android_12:
    image: assets/images/splash.png
    color: "#ffffff"
''';
    }

    if (!content.contains('flutter_launcher_icons:')) {
      content += '''
\nflutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/images/icon.png"
''';
    }

    if (!content.contains('finvoras_gen:')) {
      content += '''
\nfinvoras_gen:
  output: lib/generated/
  line_length: 80
  
  assets:
    enabled: true
    outputs:
      class_name: AppAssets
      package_parameter_enabled: false

  locales:
    enabled: true
    folder: assets/locales
    outputs:
      translation_name: AppTranslation
      keys_name: AppLocalesKeys

  integrations:
    flutter_svg: true
    lottie: true
''';
    }

    await pubspecFile.writeAsString(content);
    print('Updated pubspec.yaml with extra configs and packages');

    // Create placeholder assets if they don't exist
    final assetsDir = Directory('assets/images');
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
      print('Created assets/images directory (Please add splash.png and icon.png)');
    }

    final localesDir = Directory('assets/locales');
    if (!await localesDir.exists()) {
      await localesDir.create(recursive: true);
      print('Created assets/locales directory');
    }
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
    if (!await packagesDir.exists()) return;

    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) return;

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
    var content = await pubspecFile.readAsString();
    
    final StringBuffer dependenciesBlock = StringBuffer('\ndependencies:\n');
    for (final pkg in localPackages) {
      dependenciesBlock.writeln('  $pkg:');
      dependenciesBlock.writeln('    path: packages/$pkg');
    }

    // This is a simple append, in a real app you'd want to use a YAML parser
    // to add to the existing dependencies section.
    content += dependenciesBlock.toString();
    await pubspecFile.writeAsString(content);
  }

  Future<void> _runGenCommands() async {
    print('🎨 Generating resources...');
    await _runCommand('dart', ['run', 'flutter_native_splash:create']);
    await _runCommand('dart', ['run', 'flutter_launcher_icons']);
  }
}
