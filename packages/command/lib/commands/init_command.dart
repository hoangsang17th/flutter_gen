import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

class InitCommand extends Command {
  InitCommand() {
    // Positional argument: app-id
  }
  @override
  final name = 'init';

  @override
  final description =
      'Initialize a new Flutter project with flavors, vscode configs, and assets.';

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
    if (argResults?.rest.isEmpty ?? true) {
      print('Please provide an application ID (e.g., com.example.app)');
      return;
    }

    final appId = argResults!.rest.first;
    final parts = appId.split('.');
    if (parts.length < 2) {
      print(
        'Invalid application ID. It should be in the format com.example.app',
      );
      return;
    }

    final appName = parts.last;
    final org = parts.sublist(0, parts.length - 1).join('.');

    final splashPath = 'assets/images/logo.png';
    final iconPath = 'assets/images/logo.png';

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

    // 4. Clone submodule
    print('\n📦 Cloning packages submodule...');
    final packagesDir = Directory('packages');
    if (packagesDir.existsSync()) {
      print('⚠️  "packages" directory already exists. Skipping clone.');
    } else {
      try {
        await _runCommand('git', [
          'clone',
          '--recurse-submodules',
          'https://github.com/hoangsang17th/packages',
          'packages',
        ]);
      } catch (e) {
        print('❌ Failed to clone submodule.');
        print('👉 This might be due to network issues or missing permissions.');
        print('👉 You can try cloning it manually later:');
        print('   git clone --recurse-submodules https://github.com/hoangsang17th/packages packages');
        rethrow;
      }
    }

    // 5. Link submodule packages
    await _linkSubmodulePackages();

    // 6. Setup Melos
    await _setupMelosConfig(appName);

    // 7. Add configs for splash and icons (this does flutter pub add)
    await _setupPubspecConfigs(splashPath, iconPath);

    // 8. Run pub get
    await _runCommand('flutter', ['pub', 'get']);

    // 9. Run splash and icon gen
    print('\n🎨 Preparing splash screen and launcher icons...');
    await _runCommand('flutter', [
      'pub',
      'add',
      'dev:flutter_native_splash',
      'dev:flutter_launcher_icons',
    ]);

    bool hasAssets =
        File(splashPath).existsSync() && File(iconPath).existsSync();

    if (!hasAssets) {
      print('\n⚠️  Logo images not found at $splashPath or $iconPath');
      print('👉 Please add your logo files to the "assets/images/" directory.');
      stdout.write(
        '⌨️  Press [Enter] to run generation, or [s] to skip this step: ',
      );

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

    print('\n✅ Project initialized successfully!');
  }

  Future<void> _runCommand(
    String command,
    List<String> arguments, {
    bool throwOnError = true,
  }) async {
    print('Executing: $command ${arguments.join(' ')}');
    try {
      final result = await Process.run(command, arguments);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();

      if (result.exitCode != 0) {
        final errorMessage = StringBuffer();
        errorMessage.writeln('❌ Error executing $command (exit code ${result.exitCode})');
        if (output.isNotEmpty) {
          errorMessage.writeln('STDOUT:\n$output');
        }
        if (error.isNotEmpty) {
          errorMessage.writeln('STDERR:\n$error');
        }
        
        final msg = errorMessage.toString().trim();
        print(msg);
        if (throwOnError) {
          throw Exception(msg);
        }
      } else {
        if (output.isNotEmpty) {
          print(output);
        }
      }
    } catch (e) {
      final errorMessage = '❌ Failed to start $command: $e';
      print(errorMessage);
      if (throwOnError) {
        rethrow;
      }
    }
  }

  Future<void> _createFlavorMainFiles(String appName) async {
    final libDir = Directory('lib');
    if (!await libDir.exists()) {
      throw Exception('❌ "lib" directory not found. "flutter create" might have failed silently.');
    }

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
      "program": "lib/main_dev.dart",
      "args": ["--dart-define=FLAVOR=dev"]
    },
    {
      "name": "App (qa)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_qa.dart",
      "args": ["--dart-define=FLAVOR=qa"]
    },
    {
      "name": "App (prod)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_prod.dart",
      "args": ["--dart-define=FLAVOR=prod"]
    }
  ]
}
''';
    await launchJson.writeAsString(content);
    print('Created .vscode/launch.json');
  }

  Future<void> _setupPubspecConfigs(
    String splashPath,
    String iconPath,
  ) async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception('❌ "pubspec.yaml" not found. "flutter create" might have failed silently.');
    }

    // Add common packages FIRST so they are written to disk
    await _runCommand('flutter', [
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
        // Key doesn't exist, add it
        editor.update(path, value);
      }
    }

    ensureConfig(['flutter_native_splash'], {
      'color': '#ffffff',
      'image': splashPath,
      'android_12': {
        'image': splashPath,
        'color': '#ffffff',
      },
    });

    ensureConfig(['flutter_launcher_icons'], {
      'android': 'launcher_icon',
      'ios': true,
      'image_path': iconPath,
    });

    ensureConfig(['finvoras_gen'], {
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
    print('Updated pubspec.yaml with extra configs and packages');

    // Create placeholder assets if they don't exist
    final assetsDir = Directory('assets/images');
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
      print('Created assets/images directory (Please add logo.png)');
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
    if (!await packagesDir.exists()) {
      throw Exception('❌ "packages" directory not found. "git clone" might have failed.');
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
      final YamlNode? workspaceNode = editor.parseAt(['workspace']);
      final List workspaceList = 
          workspaceNode is YamlList ? workspaceNode.value.toList() : [];
      
      for (final pkg in localPackages) {
        final path = 'packages/$pkg';
        if (!workspaceList.contains(path)) {
          workspaceList.add(path);
        }
      }
      editor.update(['workspace'], workspaceList);
    } catch (e) {
      // workspace key doesn't exist
      editor.update(['workspace'], localPackages.map((pkg) => 'packages/$pkg').toList());
    }

    await pubspecFile.writeAsString(editor.toString());
  }

  Future<void> _runGenCommands() async {
    print('🎨 Generating resources...');
    await _runCommand('dart', ['run', 'flutter_native_splash:create']);
    await _runCommand('dart', ['run', 'flutter_launcher_icons']);
  }
}
