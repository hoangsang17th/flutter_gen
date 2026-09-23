import 'dart:io';

import 'base_command.dart';

class InitCommand extends BaseCommand {
  InitCommand() {
    argParser.addOption(
      'app-name',
      abbr: 'n',
      help: 'Formatted App Name for iOS/Android (e.g., "My Super App")',
    );
  }

  @override
  final name = 'init';

  @override
  final description =
      'Initialize a new Flutter project with core packages and submodules.';

  @override
  String get invocation => 'finvoras_gen init <application_id> [arguments]';

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
    // 1. Parse Arguments
    if (argResults?.rest.isEmpty ?? true) {
      print(
        '❌ Error: Please provide an application ID (e.g., com.example.app)',
      );
      return;
    }

    final appId = argResults!.rest.first;
    final parts = appId.split('.');
    if (parts.length < 2) {
      print('❌ Error: Invalid application ID format.');
      return;
    }
    final rawAppName = parts.last;
    final org = parts.sublist(0, parts.length - 1).join('.');
    
    // Resolve app name
    final argAppName = argResults?['app-name'] as String?;
    final appName = argAppName ?? _formatAppName(rawAppName);

    // 2. Pre-flight checks
    if (Directory('packages').existsSync()) {
      stdout.write('⚠️  "packages" directory exists. Continue? (y/n): ');
      if (stdin.readLineSync()?.toLowerCase() != 'y') return;
    }

    print('🚀 Initializing project $appName ($appId)...');

    // 3. Create Flutter App
    await flutterService.create(rawAppName, org);

    // 4. Setup Git Submodules
    if (!Directory('packages').existsSync()) {
      try {
        await gitService.clone(
          'https://github.com/hoangsang17th/packages',
          'packages',
        );
      } catch (e) {
        print('⚠️ Could not clone packages from remote git repository: $e');
        final localCandidates = [
          '../packages',
          '../../packages',
          '../../../packages',
          '/Volumes/TurboBox/Projects/idea-vault/apps/keynd/packages',
        ];
        bool copied = false;
        for (final candidate in localCandidates) {
          final dir = Directory(candidate);
          if (dir.existsSync() &&
              File('${dir.path}/app_core/pubspec.yaml').existsSync()) {
            print('📦 Copying local packages from $candidate...');
            await _copyDirectory(dir, Directory('packages'));
            copied = true;
            break;
          }
        }
        if (!copied) {
          rethrow;
        }
      }
    }

    // 5. Configure Project (YAML & Melos)
    await _configureProject(appName, appId);

    // 6. Native Setup (iOS)
    await projectService.updateIosPodfilePlatform('15.0');

    // 7. Finalize
    await flutterService.pubGet();

    // 8. CocoaPods (iOS)
    if (Platform.isMacOS && Directory('ios').existsSync() && File('ios/Podfile').existsSync()) {
      print('📦 Updating iOS CocoaPods (this might take a while)...');
      await runCommand(
        'pod',
        ['install', '--repo-update'],
        workingDirectory: 'ios',
        throwOnError: false, // Don't crash if pod fails
      );
    }

    print('\n✅ Project initialized successfully!');
  }

  Future<void> _configureProject(String appName, String appId) async {
    // 5.1 Link packages in pubspec.yaml
    final List<String> localPackages = [];
    final packagesDir = Directory('packages');
    if (packagesDir.existsSync()) {
      await for (final entity in packagesDir.list()) {
        if (entity is Directory &&
            File('${entity.path}/pubspec.yaml').existsSync()) {
          localPackages.add(entity.path.split(Platform.pathSeparator).last);
        }
      }
    }

    await projectService.updatePubspecYaml((editor) {
      // Add dependencies
      for (final pkg in localPackages) {
        editor.update(['dependencies', pkg], {'path': 'packages/$pkg'});
      }

      editor.update(['dependencies', 'flutter_localizations'], {'sdk': 'flutter'});
      editor.update(['dependencies', 'flutter_easyloading'], '^4.0.2');
      editor.update(['dependencies', 'get'], '^4.6.6');
      editor.update(['dependencies', 'firebase_core'], '^4.13.0');

      // Add workspace only if submodule packages exist
      if (localPackages.isNotEmpty) {
        final workspaceList = localPackages.map((p) => 'packages/$p').toList();
        editor.update(['workspace'], workspaceList);
      }

      // Add FinvorasGen config
      editor.update([
        'finvoras_gen',
      ], {
        'app_id': appId,
        'app_name': appName,
        'output': 'lib/generated/',
        'line_length': 80,
        'assets': {
          'enabled': true,
          'outputs': {'class_name': 'AppAssets'},
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

      editor.update(['melos'], {
        'scripts': {
          'get': {
            'run': 'melos exec -- "rm -f pubspec.lock && flutter pub get"',
            'description': 'Delete lock file and get all dependencies',
          },
          'analyze': {
            'run': 'melos exec -- "flutter analyze"',
            'description': 'Run `flutter analyze` in all packages',
          },
          'build_assets': {
            'run':
                'melos exec --concurrency=1 --dir-exists=assets -- "flutter pub get && if grep -q \\"build_runner\\" pubspec.yaml; then dart run build_runner build --delete-conflicting-outputs; else echo \'Skipping build_runner\'; fi && finvoras_gen assets -c pubspec.yaml"',
            'description': 'Generate assets code',
          },
        }
      });
    });

    // 5.2 Add standard packages via CLI
    await flutterService.addDependencies([
      'injectable',
      'get_it',
      'equatable',
      'dev:build_runner',
      'dev:json_serializable',
      'dev:injectable_generator',
      'dev:melos',
    ]);

    // 5.3 Setup Melos
    await projectService.setupMelosConfig(appName, ['packages/**']);

    // 5.4 Create assets folders
    await projectService.createDirectories(['assets/images', 'assets/locales']);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name == '.git' || name == '.dart_tool' || name == 'build') continue;
      final destPath = '${destination.path}/$name';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(destPath));
      } else if (entity is File) {
        await entity.copy(destPath);
      }
    }
  }

  String _formatAppName(String name) {
    return name
        .split('_')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ')
        .trim();
  }
}
