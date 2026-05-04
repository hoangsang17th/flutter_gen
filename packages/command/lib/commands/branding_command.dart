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
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }

    final content = await pubspec.readAsString();
    final doc = loadYaml(content);

    final appName = doc['name'];
    if (appName == null) {
      throw Exception('Missing "name" in pubspec.yaml');
    }

    String appId = 'com.example.app';
    final finvoras = doc['finvoras_gen'];
    if (finvoras is Map && finvoras['app_id'] is String) {
      appId = finvoras['app_id'];
    }

    final type = argResults!['type'];

    _logInfo('App: $appName');
    _logInfo('Type: $type');
    _logInfo('Envs: $environments');

    await _setupFlavorizr(pubspec, content, appName, appId, type);
    await _setupBrandingFiles();

    await _addDependencies();
    await _generateAssets(type);
  }

  // ==============================
  // FLAVORIZR CONFIG (SAFE MERGE)
  // ==============================
  Future<void> _setupFlavorizr(
    File file,
    String content,
    String appName,
    String appId,
    String type,
  ) async {
    final editor = YamlEditor(content);
    final doc = loadYaml(content);

    final existing = doc['flavorizr'] ?? {};
    final flavors = <String, dynamic>{};

    for (final env in environments) {
      var currentId = appId;
      if (type == 'platform' && env != 'prod') {
        currentId = '$appId.$env';
      }

      flavors[env] = {
        'app': {'name': '$appName ${env.toUpperCase()}'},
        'android': {
          'applicationId': currentId,
          'generateDummyAssets': false,
        },
        'ios': {
          'bundleId': currentId,
          'generateDummyAssets': false,
        },
      };
    }

    final merged = {
      ...existing,
      'ide': 'vscode',
      'flavors': flavors,
    };

    if (isDryRun) {
      _logWarn('[DRY RUN] flavorizr config updated');
      return;
    }

    editor.update(['flavorizr'], merged);
    await file.writeAsString(editor.toString());

    _logSuccess('Updated flavorizr config');
  }

  // ==============================
  // BRANDING YAML FILES
  // ==============================
  Future<void> _setupBrandingFiles() async {
    for (final env in environments) {
      await _writeIfChanged(
        'flutter_native_splash-$env.yaml',
        _buildSplashYaml(),
      );

      await _writeIfChanged(
        'flutter_launcher_icons-$env.yaml',
        _buildIconYaml(),
      );
    }
  }

  String _buildSplashYaml() => '''
flutter_native_splash:
  color: "#ffffff"
  image: $logoPath
  fullscreen: true

  android_12:
    color: "#ffffff"
    image: $logoPath
    icon_background_color: "#ffffff"
''';

  String _buildIconYaml() => '''
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "$logoPath"
''';

  Future<void> _writeIfChanged(String path, String content) async {
    final file = File(path);

    if (file.existsSync()) {
      final old = await file.readAsString();
      if (old == content) {
        _logInfo('Skip unchanged $path');
        return;
      }
    }

    if (isDryRun) {
      _logWarn('[DRY RUN] write $path');
      return;
    }

    await file.writeAsString(content);
    _logSuccess('Created $path');
  }

  // ==============================
  // DEPENDENCIES
  // ==============================
  Future<void> _addDependencies() async {
    await runCommand('flutter', [
      'pub',
      'add',
      'dev:flutter_flavorizr',
      'dev:flutter_native_splash',
      'dev:flutter_launcher_icons',
    ]);
  }

  // ==============================
  // GENERATION PIPELINE
  // ==============================
  Future<void> _generateAssets(String type) async {
    if (!File(logoPath).existsSync()) {
      _logWarn('Logo not found: $logoPath');

      if (!isCI) {
        stdout.write('Continue anyway? (y/N): ');
        final input = stdin.readLineSync();
        if (input?.toLowerCase() != 'y') return;
      }
    }

    // 1. flavorizr
    await runCommand('dart', ['run', 'flutter_flavorizr', '-f']);

    // 2. splash per flavor
    for (final env in environments) {
      await runCommand('dart', [
        'run',
        'flutter_native_splash:create',
        '-f',
        'flutter_native_splash-$env.yaml',
      ]);

      if (type == 'platform') {
        await _copyAndroidResources(env);
      }
    }

    // 3. icons per flavor
    for (final env in environments) {
      await runCommand('dart', [
        'run',
        'flutter_launcher_icons',
        '-f',
        'flutter_launcher_icons-$env.yaml',
      ]);
    }
  }

  // ==============================
  // ANDROID RESOURCE SPLIT (KEY FIX)
  // ==============================
  Future<void> _copyAndroidResources(String flavor) async {
    final base = Directory('android/app/src/main/res');
    final target = Directory('android/app/src/$flavor/res');

    if (!base.existsSync()) return;

    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    await runCommand('cp', ['-r', base.path + '/.', target.path]);
    _logSuccess('Copied Android res → $flavor');
  }

  // ==============================
  // LOGGING
  // ==============================
  void _logInfo(String msg) => print('ℹ️  $msg');
  void _logWarn(String msg) => print('⚠️  $msg');
  void _logError(String msg) => print('❌ $msg');
  void _logSuccess(String msg) => print('✅ $msg');
}
