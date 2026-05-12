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
  bool get isPlatform => argResults?['type'] == 'platform';
  String get logoPath => argResults!['logo'] as String;
  bool get isCI => argResults!['yes'] as bool;
  bool get isDryRun => argResults!['dry-run'] as bool;

  @override
  Future<void> run() async {
    try {
      await _execute();
      logSuccess('Branding setup completed');
    } catch (e) {
      logError(e.toString());
      exit(1);
    }
  }

  // ==============================
  // PARSE
  // ==============================
  List<String> _parseEnvs() {
    final raw = argResults?['envs'] as String? ?? 'dev,qa,prod';
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  // ==============================
  // MAIN FLOW
  // ==============================
  Future<void> _execute() async {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) throw Exception('pubspec.yaml not found');

    final content = await pubspecFile.readAsString();
    final doc = loadYaml(content);
    final appName = doc['name'] as String?;
    if (appName == null) throw Exception('Missing app name in pubspec.yaml');

    final appId = (doc['finvoras_gen'] as Map?)?['app_id'] ?? 'com.example.app';

    logInfo('App: $appName');
    logInfo('Type: ${argResults!['type']}');
    logInfo('Envs: $environments');

    _validateLogo();

    if (isPlatform) {
      await _setupFlavorizr(pubspecFile, content, appName, appId);
    } else {
      await _setupDartFlavors(appName);
    }
    await _setupBrandingFiles();

    if (isDryRun) {
      logWarn('Dry run mode → skip execution');
      return;
    }

    await _addDependencies();
    await flutterService.pubGet();
    await _generateAssets();
  }

  // ==============================
  // VALIDATION
  // ==============================
  void _validateLogo() {
    if (!File(logoPath).existsSync()) {
      logWarn('Logo not found: $logoPath');
      if (!isCI) {
        stdout.write('Continue? (y/N): ');
        if (stdin.readLineSync()?.toLowerCase() != 'y') {
          throw Exception('Aborted by user');
        }
      }
    }
  }

  // ==============================
  // FLAVORIZR (MERGE SAFE)
  // ==============================
  Future<void> _setupFlavorizr(File file, String content, String appName, String appId) async {
    final editor = YamlEditor(content);
    final doc = loadYaml(content);
    final existing = doc['flavorizr'] ?? {};
    final flavors = <String, dynamic>{};

    for (final env in environments) {
      final currentId = (env != 'prod') ? '$appId.$env' : appId;
      flavors[env] = {
        'app': {'name': '$appName ${env.toUpperCase()}'},
        'android': {'applicationId': currentId, 'generateDummyAssets': false},
        'ios': {'bundleId': currentId, 'generateDummyAssets': false},
      };
    }

    if (isDryRun) {
      logInfo('[DRY RUN] Update flavorizr config');
      return;
    }

    editor.update(['flavorizr'], {...existing, 'ide': 'vscode', 'flavors': flavors});
    await file.writeAsString(editor.toString());
    logSuccess('Flavorizr config updated');
  }

  // ==============================
  // DART FLAVORS (FOR BEHAVIOR TYPE)
  // ==============================
  Future<void> _setupDartFlavors(String appName) async {
    logInfo('Setting up Dart flavors for behavior type...');

    final libDir = Directory('lib');
    if (!libDir.existsSync()) await libDir.create(recursive: true);

    // 1. Create lib/flavors.dart
    final flavorsTemplate = await templateService.readTemplate('flavors.dart');
    final enumValues = environments.map((e) => '  $e,').join('\n');
    final titleCases = environments.map((e) {
      return '''      case Flavor.$e:
        return '$appName ${e.toUpperCase()}';''';
    }).join('\n');
    final baseUrlCases = environments.map((e) {
      return '''      case Flavor.$e:
        return 'https://$e-api.example.com';''';
    }).join('\n');

    final flavorsContent = templateService.replace(flavorsTemplate, {
      'FLAVOR_ENUM_VALUES': enumValues,
      'FLAVOR_TITLE_CASES': titleCases,
      'FLAVOR_BASE_URL_CASES': baseUrlCases,
    });
    await _writeIfChanged('lib/flavors.dart', flavorsContent);

    // 2. Create lib/main_<env>.dart
    final mainTemplate = await templateService.readTemplate('main_flavor.dart');
    for (final env in environments) {
      final mainContent = templateService.replace(mainTemplate, {
        'FLAVOR_NAME': env,
      });
      await _writeIfChanged('lib/main_$env.dart', mainContent);
    }

    logSuccess('Dart flavors setup completed');

    // 3. Create lib/app.dart
    final appTemplate = await templateService.readTemplate('app.dart');
    await _writeIfChanged('lib/app.dart', appTemplate);

    // 4. Create lib/pages/my_home_page.dart
    final pagesDir = Directory('lib/pages');
    if (!pagesDir.existsSync()) await pagesDir.create(recursive: true);
    
    final homeTemplate = await templateService.readTemplate('my_home_page.dart');
    await _writeIfChanged('lib/pages/my_home_page.dart', homeTemplate);
  }

  // ==============================
  // BRANDING FILES (IDEMPOTENT)
  // ==============================
  Future<void> _setupBrandingFiles() async {
    final targets = isPlatform ? environments : [''];
    for (final env in targets) {
      final suffix = env.isEmpty ? '' : '-$env';
      
      final splashTemplate = await templateService.readTemplate('splash.yaml');
      final splashContent = templateService.replace(splashTemplate, {
        'LOGO_PATH': logoPath,
      });
      await _writeIfChanged('flutter_native_splash$suffix.yaml', splashContent);

      final iconsTemplate = await templateService.readTemplate('icons.yaml');
      final iconsContent = templateService.replace(iconsTemplate, {
        'LOGO_PATH': logoPath,
      });
      await _writeIfChanged('flutter_launcher_icons$suffix.yaml', iconsContent);
    }
  }

  Future<void> _writeIfChanged(String path, String content) async {
    final file = File(path);
    if (file.existsSync() && await file.readAsString() == content) {
      logInfo('Skip unchanged $path');
      return;
    }

    if (isDryRun) {
      logInfo('[DRY RUN] Write $path');
      return;
    }

    await file.writeAsString(content);
    logSuccess('Created $path');
  }

  // ==============================
  // DEPENDENCIES
  // ==============================
  Future<void> _addDependencies() async {
    final deps = ['dev:flutter_native_splash', 'dev:flutter_launcher_icons'];
    if (isPlatform) deps.add('dev:flutter_flavorizr');
    await flutterService.addDependencies(deps);
  }

  // ==============================
  // GENERATION
  // ==============================
  Future<void> _generateAssets() async {
    if (isPlatform) {
      await projectService.cleanupDefaultAssets();
      await projectService.fixIosAppIconName();
      await _runCommand('dart', ['run', 'flutter_flavorizr', '--force']);
    }

    final targets = isPlatform ? environments : [''];
    for (final env in targets) {
      final suffix = env.isEmpty ? '' : '-$env';

      // splash
      final splashArgs = ['run', 'flutter_native_splash:create'];
      if (env.isNotEmpty) splashArgs.addAll(['-f', env]);
      await _runCommand('dart', splashArgs);

      if (env.isNotEmpty) await _copyAndroidResources(env);

      // icon
      final iconArgs = ['run', 'flutter_launcher_icons'];
      if (env.isNotEmpty) iconArgs.addAll(['-f', 'flutter_launcher_icons$suffix.yaml']);
      await _runCommand('dart', iconArgs);
    }
  }

  // ==============================
  // ANDROID COPY (CROSS-PLATFORM)
  // ==============================
  Future<void> _copyAndroidResources(String flavor) async {
    final src = Directory('android/app/src/main/res');
    final dest = Directory('android/app/src/$flavor/res');

    if (!src.existsSync()) return;
    if (dest.existsSync()) await dest.delete(recursive: true);

    await for (final entity in src.list(recursive: true)) {
      final newPath = entity.path.replaceFirst(src.path, dest.path);
      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await File(newPath).parent.create(recursive: true);
        await entity.copy(newPath);
      }
    }
    logSuccess('Copied Android res → $flavor');
  }

  // ==============================
  // COMMAND WRAPPER (STREAMING)
  // ==============================
  Future<void> _runCommand(String cmd, List<String> args) async {
    logInfo('$cmd ${args.join(' ')}');
    final process = await Process.start(cmd, args, runInShell: true);
    await stdout.addStream(process.stdout);
    await stderr.addStream(process.stderr);
    if (await process.exitCode != 0) throw Exception('Command failed: $cmd');
  }
}
