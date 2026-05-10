import 'dart:io';

import 'package:finvoras_gen/src/core/flutter_generator.dart';
import 'package:finvoras_gen/src/templates/templates.dart';
import 'package:finvoras_gen/src/utils/template_helper.dart';
import 'package:yaml/yaml.dart';

import 'base_command.dart';

class PrepareCommand extends BaseCommand {
  PrepareCommand() {
    argParser.addOption(
      'stack',
      abbr: 's',
      defaultsTo: 'bloc',
      allowed: ['bloc', 'getx'],
      help: 'Choose the state management stack (bloc or getx)',
    );
  }

  @override
  final name = 'prepare';

  @override
  final description =
      'Prepare project with DI, main setup, and core configurations.';

  @override
  Future<void> run() async {
    try {
      await _execute();
      print('\n✅ Project prepared successfully!');
    } catch (e) {
      print('\n💥 Preparation failed!');
      print(e);
    }
  }

  Future<void> _execute() async {
    // 1. Pre-flight checks
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception(
        'pubspec.yaml not found. Please run this command in a Flutter project root.',
      );
    }

    print('🚀 Preparing project...');

    // 2. Create Language JSON
    await _setupLocales();

    // 3. Setup DI
    await _setupDI();

    // 4. Setup Core Config (prepare.dart)
    await _setupPrepareConfig();

    // 5. Update main.dart
    await _updateMainDart();

    // 6. Add stack-specific dependencies
    await _addStackDependencies();

    // 7. Generate Translation & DI
    await _generateFiles();
  }

  Future<void> _setupLocales() async {
    final config = projectService.readPubspecConfig([
      'finvoras_gen',
      'locales',
    ]);
    String folder = 'assets/locales';
    if (config is Map && config['folder'] is String) {
      folder = config['folder'];
    }

    await projectService.createDirectories([folder]);

    final enFile = File('$folder/en.json');
    if (!enFile.existsSync()) {
      await enFile.writeAsString(
        TemplateHelper.generate(PrepareTemplates.localeJson, {
          'appName': 'My App',
        }),
      );
      print('📝 Created $folder/en.json');
    }

    final viFile = File('$folder/vi.json');
    if (!viFile.existsSync()) {
      await viFile.writeAsString(
        TemplateHelper.generate(PrepareTemplates.localeJson, {
          'appName': 'Ứng dụng của tôi',
        }),
      );
      print('📝 Created $folder/vi.json');
    }
  }

  Future<void> _setupDI() async {
    await projectService.createDirectories(['lib/src/di']);
    final file = File('lib/src/di/injection.dart');

    if (file.existsSync()) return;

    await file.writeAsString(PrepareTemplates.injectionDart);
    print('📝 Created lib/src/di/injection.dart');
  }

  Future<void> _setupPrepareConfig() async {
    await projectService.createDirectories(['lib/core/config']);
    final file = File('lib/core/config/prepare.dart');

    await file.writeAsString(PrepareTemplates.prepareDart);
    print('📝 Created lib/core/config/prepare.dart');
  }

  Future<void> _updateMainDart() async {
    final mainFile = File('lib/main.dart');
    final stack = argResults?['stack'] as String? ?? 'bloc';

    String imports;
    String materialApp;
    String router = '';

    if (stack == 'bloc') {
      imports = "import 'package:go_router/go_router.dart';";
      materialApp = PrepareTemplates.blocMaterialApp;
      router = PrepareTemplates.blocRouter;
    } else {
      imports = "import 'package:get/get.dart';";
      materialApp = PrepareTemplates.getxMaterialApp;
    }

    final content = TemplateHelper.generate(PrepareTemplates.mainDart, {
      'imports': imports,
      'materialApp': materialApp,
      'router': router,
    });

    await mainFile.writeAsString(content);
    print('📝 Updated lib/main.dart (stack: $stack)');
  }

  Future<void> _addStackDependencies() async {
    final stack = argResults?['stack'] as String? ?? 'bloc';
    final List<String> deps = [];

    if (stack == 'bloc') {
      deps.addAll(['flutter_bloc', 'go_router']);
    } else if (stack == 'getx') {
      deps.add('get');
    }

    if (deps.isNotEmpty) {
      print('📦 Adding stack dependencies: ${deps.join(', ')}...');
      await flutterService.addDependencies(deps);
    }
  }

  Future<void> _generateFiles() async {
    print('🔄 Generating translation and DI files...');

    // 1. Run pub get
    await flutterService.pubGet();

    // 2. Generate Translations using internal FlutterGenerator
    print('🏃 Generating translations...');
    final generator = FlutterGenerator(File('pubspec.yaml'));
    await generator.build();

    // 3. Run build_runner for DI
    final pubspecContent = await File('pubspec.yaml').readAsString();
    final pubspec = loadYaml(pubspecContent);
    final devDeps = pubspec['dev_dependencies'] as Map?;

    if (devDeps?.containsKey('build_runner') ?? false) {
      print('🏃 Running build_runner for DI...');
      await flutterService.run([
        'pub',
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ]);
    }
  }
}
