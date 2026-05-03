import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'base_command.dart';

class BrandingCommand extends BaseCommand {
  @override
  final name = 'branding';

  @override
  final description =
      'Setup flavors, native splash screen, and launcher icons.';

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

  Future<void> _execute() async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception(
          '❌ "pubspec.yaml" not found. Please run this command in a Flutter project root.');
    }

    final pubspecContent = await pubspecFile.readAsString();
    final doc = loadYaml(pubspecContent);
    final appName = doc['name'] as String;

    print('🚀 Setting up branding for $appName...');

    // 1. Setup Flavors
    print('🛠 Setting up flavors (dev, qa, prod)...');
    await _createFlavorMainFiles(appName);
    await _setupVSCodeLauncher(appName);

    // 2. Setup Pubspec
    await _setupBrandingPubspecConfigs();

    // 3. Add Branding Packages
    print('\n📦 Adding branding dependencies...');
    await runCommand('flutter', [
      'pub',
      'add',
      'dev:flutter_native_splash',
      'dev:flutter_launcher_icons',
    ]);

    // 4. Generate Assets
    await _runGenCommands();

    print('\n✅ Branding setup successfully!');
  }

  Future<void> _createFlavorMainFiles(String appName) async {
    final libDir = Directory('lib');
    if (!await libDir.exists()) {
      throw Exception('❌ "lib" directory not found.');
    }

    final flavors = ['dev', 'qa', 'prod'];
    for (final flavor in flavors) {
      final file = File('lib/main_$flavor.dart');
      if (file.existsSync()) {
        print('⚠️  ${file.path} already exists. Skipping.');
        continue;
      }
      final content = '''
import 'package:flutter/material.dart';
import 'main.dart' as app;

void main() {
  // TODO: Add $flavor specific configuration here
  app.main();
}
''';
      await file.writeAsString(content);
      print('Created ${file.path}');
    }
  }

  Future<void> _setupVSCodeLauncher(String appName) async {
    final vscodeDir = Directory('.vscode');
    if (!await vscodeDir.exists()) {
      await vscodeDir.create();
    }

    final launchJson = File('.vscode/launch.json');
    if (launchJson.existsSync()) {
      print('⚠️  .vscode/launch.json already exists. Skipping.');
      return;
    }
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

  Future<void> _setupBrandingPubspecConfigs() async {
    final pubspecFile = File('pubspec.yaml');
    final splashPath = 'assets/images/logo.png';
    final iconPath = 'assets/images/logo.png';

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

    await pubspecFile.writeAsString(editor.toString());
    print('Updated pubspec.yaml with branding configs');
  }

  Future<void> _runGenCommands() async {
    final splashPath = 'assets/images/logo.png';
    final iconPath = 'assets/images/logo.png';

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
        return;
      }
      
      if (!File(splashPath).existsSync() || !File(iconPath).existsSync()) {
        print('❌ Files still missing. Skipping generation to avoid errors.');
        print('💡 You can run it later with:');
        print('   dart run flutter_native_splash:create');
        print('   dart run flutter_launcher_icons');
        return;
      }
    }

    print('🎨 Generating resources...');
    await runCommand('dart', ['run', 'flutter_native_splash:create']);
    await runCommand('dart', ['run', 'flutter_launcher_icons']);
  }
}
