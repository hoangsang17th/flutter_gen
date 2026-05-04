import 'dart:io';

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
    final appName = parts.last;
    final org = parts.sublist(0, parts.length - 1).join('.');

    // 2. Pre-flight checks
    if (Directory('packages').existsSync()) {
      stdout.write('⚠️  "packages" directory exists. Continue? (y/n): ');
      if (stdin.readLineSync()?.toLowerCase() != 'y') return;
    }

    print('🚀 Initializing project $appName ($appId)...');

    // 3. Create Flutter App
    await flutterService.create(appName, org);

    // 4. Setup Git Submodules
    if (!Directory('packages').existsSync()) {
      await gitService.clone(
        'https://github.com/hoangsang17th/packages',
        'packages',
      );
    }

    // 5. Configure Project (YAML & Melos)
    await _configureProject(appName, appId);

    // 6. Native Setup (iOS)
    await projectService.updateIosPodfilePlatform('15.0');

    // 7. Finalize
    await flutterService.pubGet();

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
    });

    // 5.2 Add standard packages via CLI
    await flutterService.addDependencies([
      'injectable',
      'get_it',
      'equatable',
      'dev:build_runner',
      'dev:json_serializable',
      'dev:injectable_generator',
    ]);

    // 5.3 Setup Melos
    await projectService.setupMelosConfig(appName, ['packages/**']);

    // 5.4 Create assets folders
    await projectService.createDirectories(['assets/images', 'assets/locales']);
  }
}
