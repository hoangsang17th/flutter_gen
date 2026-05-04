import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'base_command.dart';

class BrandingCommand extends BaseCommand {
  BrandingCommand() {
    argParser
      ..addOption(
        'type',
        abbr: 't',
        defaultsTo: 'behavior',
        allowed: ['behavior', 'platform'],
        help: 'Flavor type: behavior (single ID) or platform (multi ID)',
      )
      ..addOption(
        'envs',
        abbr: 'e',
        defaultsTo: 'dev,qa,prod',
        help: 'Comma-separated environments',
      )
      ..addOption(
        'logo',
        defaultsTo: 'assets/images/logo.png',
        help: 'Path to logo image',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        defaultsTo: false,
        help: 'Skip confirmation prompts (CI mode)',
      )
      ..addFlag(
        'dry-run',
        defaultsTo: false,
        help: 'Preview changes without writing files',
      );
  }

  @override
  final name = 'branding';

  @override
  final description = 'Setup flavors, splash, and icons (production-grade).';

  late final List<String> environments = _parseEnvs();

  String get logoPath => argResults!['logo'];
  bool get isCI => argResults!['yes'];
  bool get isDryRun => argResults!['dry-run'];

  @override
  Future<void> run() async {
    try {
      await _execute();
      _logSuccess('Branding setup completed');
    } catch (e) {
      _logError('Branding setup failed: $e');
      exit(1);
    }
  }

  List<String> _parseEnvs() {
    final raw = argResults?['envs'] ?? 'dev,qa,prod';
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _execute() async {
    final appName = projectService.readPubspecConfig(['name']);
    if (appName == null) throw Exception('pubspec.yaml error');

    final appId =
        projectService.readPubspecConfig(['finvoras_gen', 'app_id']) ??
            'com.example.app';
    final type = argResults!['type'];

    _logInfo('App: $appName | Type: $type | Envs: $environments');

    // 1. Setup Flavorizr
    await _setupFlavorizr(appName, appId, type);

    // 2. Setup Branding Files
    await _setupBrandingFiles();

    // 3. Add Dependencies
    await flutterService.addDependencies([
      'dev:flutter_flavorizr',
      'dev:flutter_native_splash',
      'dev:flutter_launcher_icons',
    ]);

    // 4. Generate Assets
    await _generateAssets(type);
  }

  Future<void> _setupFlavorizr(
      String appName, String appId, String type) async {
    await projectService.updatePubspecYaml((editor) {
      final flavors = <String, dynamic>{};
      for (final env in environments) {
        final currentId =
            (type == 'platform' && env != 'prod') ? '$appId.$env' : appId;
        flavors[env] = {
          'app': {'name': '$appName ${env.toUpperCase()}'},
          'android': {'applicationId': currentId, 'generateDummyAssets': false},
          'ios': {'bundleId': currentId, 'generateDummyAssets': false},
        };
      }
      editor.update(['flavorizr'], {'ide': 'vscode', 'flavors': flavors});
    });
    _logSuccess('Updated flavorizr config');
  }

  Future<void> _setupBrandingFiles() async {
    for (final env in environments) {
      final splashPath = 'flutter_native_splash-$env.yaml';
      final iconPath = 'flutter_launcher_icons-$env.yaml';

      final splashContent = '''
flutter_native_splash:
  color: "#ffffff"
  image: $logoPath
  fullscreen: true
''';
      final iconContent = '''
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "$logoPath"
''';

      await File(splashPath).writeAsString(splashContent);
      await File(iconPath).writeAsString(iconContent);
      _logSuccess('Created branding configs for $env');
    }
  }

  Future<void> _generateAssets(String type) async {
    // 1. flavorizr
    await flutterService.run(['run', 'flutter_flavorizr', '-f']);

    // 2. splash & icons per flavor
    for (final env in environments) {
      await flutterService.run([
        'run',
        'flutter_native_splash:create',
        '-f',
        'flutter_native_splash-$env.yaml'
      ]);
      await flutterService.run([
        'run',
        'flutter_launcher_icons',
        '-f',
        'flutter_launcher_icons-$env.yaml'
      ]);

      if (type == 'platform') {
        await _copyAndroidResources(env);
      }
    }
  }

  Future<void> _copyAndroidResources(String flavor) async {
    final base = 'android/app/src/main/res';
    final target = 'android/app/src/$flavor/res';
    if (Directory(base).existsSync()) {
      await Directory(target).create(recursive: true);
      await flutterService.run(['cp', '-r', '$base/.', target]);
    }
  }

  void _logInfo(String msg) => print('ℹ️  $msg');
  void _logSuccess(String msg) => print('✅ $msg');
  void _logError(String msg) => print('X $msg');
}
