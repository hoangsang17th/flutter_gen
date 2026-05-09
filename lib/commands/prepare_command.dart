import 'dart:io';
import 'package:finvoras_gen/src/templates/templates.dart';
import 'package:finvoras_gen/src/utils/template_helper.dart';
import 'package:yaml/yaml.dart';
import 'package:finvoras_gen/src/core/flutter_generator.dart';
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
  final description = 'Prepare project with DI, main setup, and core configurations.';

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
      throw Exception('pubspec.yaml not found. Please run this command in a Flutter project root.');
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
    final config = projectService.readPubspecConfig(['finvoras_gen', 'locales']);
    String folder = 'assets/locales';
    if (config is Map && config['folder'] is String) {
      folder = config['folder'];
    }

    await projectService.createDirectories([folder]);

    final enFile = File('$folder/en.json');
    if (!enFile.existsSync()) {
      await enFile.writeAsString('{\n  "app_name": "My App"\n}\n');
      print('📝 Created $folder/en.json');
    }

    final viFile = File('$folder/vi.json');
    if (!viFile.existsSync()) {
      await viFile.writeAsString('{\n  "app_name": "Ứng dụng của tôi"\n}\n');
      print('📝 Created $folder/vi.json');
    }
  }

  Future<void> _setupDI() async {
    await projectService.createDirectories(['lib/src/di']);
    final file = File('lib/src/di/injection.dart');
    
    if (file.existsSync()) return;

    final content = '''
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async => getIt.init();
''';
    await file.writeAsString(content);
    print('📝 Created lib/src/di/injection.dart');
  }

  Future<void> _setupPrepareConfig() async {
    await projectService.createDirectories(['lib/core/config']);
    final file = File('lib/core/config/prepare.dart');

    final content = TemplateHelper.render(Templates.prepareDart, {});

    await file.writeAsString(content);
    print('📝 Created lib/core/config/prepare.dart');
  }

  Future<void> _updateMainDart() async {
    final mainFile = File('lib/main.dart');
    final stack = argResults?['stack'] as String? ?? 'bloc';

    final content = TemplateHelper.render(Templates.mainDart, {
      'isBloc': stack == 'bloc',
      'isGetX': stack == 'getx',
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
        '--delete-conflicting-outputs'
      ]);
    }
  }
}
