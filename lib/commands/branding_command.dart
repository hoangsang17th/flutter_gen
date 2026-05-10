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

  String get logoPath => argResults!['logo'] as String;
  bool get isCI => argResults!['yes'] as bool;
  bool get isDryRun => argResults!['dry-run'] as bool;

  @override
  Future<void> run() async {
    try {
      await _execute();
      _logSuccess('Branding setup completed');
    } catch (e) {
      _logError(e.toString());
      exit(1);
    }
  }

  // ==============================
  // PARSE
  // ==============================
  List<String> _parseEnvs() {
    final raw = argResults?['envs'] as String? ?? 'dev,qa,prod';
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ==============================
  // MAIN FLOW
  // ==============================
  Future<void> _execute() async {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }

    final content = await pubspec.readAsString();
    final doc = loadYaml(content);

    final appName = doc['name'] as String?;
    if (appName == null) {
      throw Exception('Missing app name in pubspec.yaml');
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

    _validateLogo();

    await _setupFlavorizr(pubspec, content, appName, appId, type);
    await _setupBrandingFiles();

    if (isDryRun) {
      _logWarn('Dry run mode → skip execution');
      return;
    }

    await _addDependencies();
    await _generateAssets(type);
  }

  // ==============================
  // VALIDATION
  // ==============================
  void _validateLogo() {
    if (!File(logoPath).existsSync()) {
      _logWarn('Logo not found: $logoPath');

      if (!isCI) {
        stdout.write('Continue? (y/N): ');
        final input = stdin.readLineSync();
        if (input?.toLowerCase() != 'y') {
          throw Exception('Aborted by user');
        }
      }
    }
  }

  // ==============================
  // FLAVORIZR (MERGE SAFE)
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
      final currentId =
          (type == 'platform' && env != 'prod') ? '$appId.$env' : appId;

      flavors[env] = {
        'app': {'name': '$appName ${env.toUpperCase()}'},
        'android': {'applicationId': currentId, 'generateDummyAssets': false},
        'ios': {'bundleId': currentId, 'generateDummyAssets': false},
      };
    }

    final merged = {...existing, 'ide': 'vscode', 'flavors': flavors};

    if (isDryRun) {
      _logInfo('[DRY RUN] Update flavorizr config');
      return;
    }

    editor.update(['flavorizr'], merged);
    await file.writeAsString(editor.toString());

    _logSuccess('Flavorizr config updated');
  }

  // ==============================
  // BRANDING FILES (IDEMPOTENT)
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
      _logInfo('[DRY RUN] Write $path');
      return;
    }

    await file.writeAsString(content);
    _logSuccess('Created $path');
  }

  // ==============================
  // DEPENDENCIES
  // ==============================
  Future<void> _addDependencies() async {
    await _runCommand('flutter', [
      'pub',
      'add',
      'dev:flutter_flavorizr',
      'dev:flutter_native_splash',
      'dev:flutter_launcher_icons',
    ]);
  }

  // ==============================
  // GENERATION
  // ==============================
  Future<void> _generateAssets(String type) async {
    // flavorizr
    await _runCommand('dart', ['run', 'flutter_flavorizr', '-f']);

    for (final env in environments) {
      // splash
      await _runCommand('dart', [
        'run',
        'flutter_native_splash:create',
        '-f',
        env,
      ]);

      // copy resource immediately (critical)
      if (type == 'platform') {
        await _copyAndroidResources(env);
      }

      // icon
      await _runCommand('dart', [
        'run',
        'flutter_launcher_icons',
        '-f',
        'flutter_launcher_icons-$env.yaml',
      ]);
    }

    // if (type == 'platform') {
    await projectService.fixIosAppIconName();
    // }

    await projectService.cleanupDefaultAssets();
  }

  // ==============================
  // ANDROID COPY (CROSS-PLATFORM)
  // ==============================
  Future<void> _copyAndroidResources(String flavor) async {
    final src = Directory('android/app/src/main/res');
    final dest = Directory('android/app/src/$flavor/res');

    if (!src.existsSync()) return;

    if (dest.existsSync()) {
      await dest.delete(recursive: true);
    }

    await for (final entity in src.list(recursive: true)) {
      final newPath = entity.path.replaceFirst(src.path, dest.path);

      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await File(newPath).create(recursive: true);
        await entity.copy(newPath);
      }
    }

    _logSuccess('Copied Android res → $flavor');
  }

  // ==============================
  // COMMAND WRAPPER (FAIL FAST)
  // ==============================
  Future<void> _runCommand(String cmd, List<String> args) async {
    _logInfo('$cmd ${args.join(' ')}');

    final process = await Process.start(cmd, args, runInShell: true);
    await stdout.addStream(process.stdout);
    await stderr.addStream(process.stderr);

    final code = await process.exitCode;

    if (code != 0) {
      throw Exception('Command failed: $cmd');
    }
  }

  // ==============================
  // LOG
  // ==============================
  void _logInfo(String msg) => print('ℹ️  $msg');
  void _logWarn(String msg) => print('⚠️  $msg');
  void _logError(String msg) => print('❌ $msg');
  void _logSuccess(String msg) => print('✅ $msg');
}
