import 'dart:io';

import 'package:finvoras_gen/src/core/flutter_generator.dart';
import 'package:finvoras_gen/src/services/flutter_service.dart';

import 'base_command.dart';

class PrepareCommand extends BaseCommand {
  PrepareCommand() {
    argParser
      ..addOption(
        'stack',
        abbr: 's',
        defaultsTo: 'bloc',
        allowed: ['bloc', 'getx'],
        help: 'State management stack for generic profile.',
      )
      ..addOption(
        'profile',
        defaultsTo: 'generic',
        allowed: ['generic', 'finvoras_mobile'],
        help: 'Preparation profile.',
      )
      ..addOption(
        'runtime',
        allowed: ['flutter', 'fvm'],
        help: 'Runtime for flutter commands. Required for finvoras_mobile.',
      )
      ..addOption(
        'workspace',
        defaultsTo: 'all',
        help: 'Workspace target: all|root|packages/a,packages/b',
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Non-interactive mode.',
      );
  }

  @override
  final name = 'prepare';

  @override
  final description =
      'Prepare project with profile-based setup and workspace bootstrap.';

  @override
  Future<void> run() async {
    try {
      await _execute();
      logSuccess('Project prepared successfully');
    } catch (e) {
      logError('Preparation failed: $e');
    }
  }

  Future<void> _execute() async {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception(
        'pubspec.yaml not found. Please run this command in project root.',
      );
    }

    final profile = argResults?['profile'] as String? ?? 'generic';
    if (profile == 'finvoras_mobile') {
      await _prepareFinvorasMobile();
      return;
    }
    await _prepareGeneric();
  }

  Future<void> _prepareGeneric() async {
    final stack = argResults?['stack'] as String? ?? 'bloc';
    logInfo('Preparing project with generic profile (stack: $stack)...');

    await _setupLocales();
    await _setupDI();
    await _setupPrepareConfig();
    await _updateMainDart(stack: stack);
    await _addStackDependencies(stack: stack);
    await _generateFiles();
  }

  Future<void> _prepareFinvorasMobile() async {
    final runtimeArg = argResults?['runtime'] as String?;
    if (runtimeArg == null) {
      throw Exception(
        'Missing --runtime. For finvoras_mobile, use --runtime flutter|fvm',
      );
    }

    final runtime =
        runtimeArg == 'fvm' ? FlutterRuntime.fvm : FlutterRuntime.flutter;
    flutterService.setRuntime(runtime);

    final workspaceOption = argResults?['workspace'] as String? ?? 'all';
    logInfo(
      'Preparing finvoras_mobile (runtime: $runtimeArg, workspace: $workspaceOption)',
    );

    await _rewriteFinvorasMobileCoreFiles();
    await _normalizePubspecForMonorepo();

    final workspacePackages = workspaceService.readWorkspacePackages();
    final selectedPackages = workspaceService.selectTargets(
      workspaceOption: workspaceOption,
      workspacePackages: workspacePackages,
    );

    final report = <_StepReport>[];

    // 1) root deps sync
    await _trackStep(report, 'root:pub_get', () async {
      await flutterService.pubGet();
    });

    // 2) package deps sync
    for (final pkg in selectedPackages) {
      await _trackStep(report, '$pkg:pub_get', () async {
        if (!workspaceService.isPackageDirectory(pkg)) {
          throw Exception('Missing package directory: $pkg');
        }
        await flutterService.pubGet(cwd: pkg);
      });
    }

    // 3) codegen package
    for (final pkg in selectedPackages) {
      if (!workspaceService.isPackageDirectory(pkg)) {
        report.add(_StepReport.skipped('$pkg:codegen', 'missing package'));
        continue;
      }

      if (workspaceService.hasBuildRunner(pkg)) {
        await _trackStep(
          report,
          '$pkg:build_runner',
          () async {
            await flutterService.runBuildRunner(cwd: pkg);
          },
          continueOnFailure: true,
        );
      } else {
        report.add(_StepReport.skipped('$pkg:build_runner', 'no build_runner'));
      }

      if (workspaceService.hasFinvorasGen(pkg)) {
        await _trackStep(
          report,
          '$pkg:finvoras_assets',
          () async {
            await flutterService.runFinvorasAssets(cwd: pkg);
          },
          continueOnFailure: true,
        );
      } else {
        report.add(
          _StepReport.skipped('$pkg:finvoras_assets', 'no finvoras_gen'),
        );
      }
    }

    // 4) codegen root
    if (workspaceService.hasBuildRunner('.')) {
      await _trackStep(
        report,
        'root:build_runner',
        () async {
          await flutterService.runBuildRunner();
        },
        continueOnFailure: true,
      );
    } else {
      report.add(_StepReport.skipped('root:build_runner', 'no build_runner'));
    }
    if (workspaceService.hasFinvorasGen('.')) {
      await _trackStep(
        report,
        'root:finvoras_assets',
        () async {
          await flutterService.runFinvorasAssets();
        },
        continueOnFailure: true,
      );
    } else {
      report
          .add(_StepReport.skipped('root:finvoras_assets', 'no finvoras_gen'));
    }

    // 5) verify
    await _trackStep(
      report,
      'verify',
      () async {
        _verifyFinvorasFiles();
      },
      continueOnFailure: true,
    );

    _printSummary(report);
  }

  Future<void> _rewriteFinvorasMobileCoreFiles() async {
    await projectService.createDirectories(['lib/core/configs/bootstrap']);
    await File('lib/main.dart').writeAsString(_mainDartTemplate);
    await File('lib/core/configs/di.dart').writeAsString(_diTemplate);
    await File('lib/core/configs/prepare_environment.dart')
        .writeAsString(_prepareEnvironmentTemplate);
    logInfo('Rewrote critical files for finvoras_mobile profile');
  }

  Future<void> _normalizePubspecForMonorepo() async {
    final workspace = workspaceService.readWorkspacePackages();
    final packageNames = workspace
        .map((path) => path.split('/').last.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    await projectService.updatePubspecYaml((editor) {
      if (workspace.isNotEmpty) {
        editor.update(['workspace'], workspace);
      }

      for (final pkg in packageNames) {
        editor.update(['dependencies', pkg], {'path': 'packages/$pkg'});
      }

      editor.update([
        'finvoras_gen',
      ], {
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
      });

      editor.update([
        'melos',
        'scripts',
        'get',
      ], {
        'run': 'melos exec -- "rm -f pubspec.lock && flutter pub get"',
        'description': 'Delete lock file and get all dependencies',
      });
      editor.update([
        'melos',
        'scripts',
        'analyze',
      ], {
        'run': 'melos exec -- "flutter analyze"',
        'description': 'Run `flutter analyze` in all packages',
      });
      editor.update([
        'melos',
        'scripts',
        'build_assets',
      ], {
        'run':
            'melos exec --concurrency=1 --dir-exists=assets -- "flutter pub get && if grep -q \\"build_runner\\" pubspec.yaml; then flutter pub run build_runner build --delete-conflicting-outputs; else echo \'Skipping build_runner\'; fi && finvoras_gen -c pubspec.yaml"',
        'description': 'Generate assets code',
      });
    });
  }

  void _verifyFinvorasFiles() {
    final required = [
      'lib/main.dart',
      'lib/core/configs/di.dart',
      'lib/core/configs/prepare_environment.dart',
      'pubspec.yaml',
    ];
    for (final path in required) {
      if (!File(path).existsSync()) {
        throw Exception('Missing required file after prepare: $path');
      }
    }
  }

  Future<void> _trackStep(
    List<_StepReport> reports,
    String name,
    Future<void> Function() action, {
    bool continueOnFailure = false,
  }) async {
    try {
      await action();
      reports.add(_StepReport.done(name));
    } catch (e) {
      reports.add(_StepReport.failed(name, e.toString()));
      if (!continueOnFailure) rethrow;
    }
  }

  void _printSummary(List<_StepReport> reports) {
    print('\n=== Prepare Summary ===');
    for (final item in reports) {
      print(
        '[${item.status}] ${item.step}${item.message == null ? '' : ' - ${item.message}'}',
      );
    }
    print('=======================');
  }

  Future<void> _setupLocales() async {
    final config =
        projectService.readPubspecConfig(['finvoras_gen', 'locales']);
    var folder = 'assets/locales';
    if (config is Map && config['folder'] is String) {
      folder = config['folder'] as String;
    }

    await projectService.createDirectories([folder]);
    final enFile = File('$folder/en.json');
    if (!enFile.existsSync()) {
      await enFile.writeAsString('{\n  "app_name": "My App"\n}\n');
      logInfo('Created $folder/en.json');
    }
    final viFile = File('$folder/vi.json');
    if (!viFile.existsSync()) {
      await viFile.writeAsString('{\n  "app_name": "Ung dung cua toi"\n}\n');
      logInfo('Created $folder/vi.json');
    }
  }

  Future<void> _setupDI() async {
    await projectService.createDirectories(['lib/src/di']);
    final file = File('lib/src/di/injection.dart');
    if (file.existsSync()) return;
    await file.writeAsString('''
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async => getIt.init();
''');
    logInfo('Created lib/src/di/injection.dart');
  }

  Future<void> _setupPrepareConfig() async {
    await projectService.createDirectories(['lib/core/config']);
    final file = File('lib/core/config/prepare.dart');
    await file.writeAsString('''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

Future<void> prepareApp(WidgetsBinding binding) async {
  ErrorWidget.builder = (_) => const SizedBox.shrink();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  FlutterNativeSplash.remove();
}
''');
    logInfo('Rewrote lib/core/config/prepare.dart');
  }

  Future<void> _updateMainDart({required String stack}) async {
    final mainFile = File('lib/main.dart');
    final import = stack == 'bloc'
        ? "import 'package:go_router/go_router.dart';"
        : "import 'package:get/get.dart';";
    final app = stack == 'bloc'
        ? 'MaterialApp.router(routerConfig: _router)'
        : 'GetMaterialApp(home: const Scaffold(body: Center(child: Text(\'App Prepared with GetX!\'))))';

    await mainFile.writeAsString('''
import 'package:flutter/material.dart';
$import
import 'core/config/prepare.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await prepareApp(binding);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => $app;
}

${stack == 'bloc' ? "final _router = GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())]);" : ""}
''');
    logInfo('Rewrote lib/main.dart (generic profile, stack: $stack)');
  }

  Future<void> _addStackDependencies({required String stack}) async {
    final deps = <String>[];
    if (stack == 'bloc') {
      deps.addAll(['flutter_bloc', 'go_router']);
    } else {
      deps.add('get');
    }
    if (deps.isNotEmpty) {
      await flutterService.addDependencies(deps);
    }
  }

  Future<void> _generateFiles() async {
    await flutterService.pubGet();
    await FlutterGenerator(File('pubspec.yaml')).build();
    if (workspaceService.hasBuildRunner('.')) {
      await flutterService.runBuildRunner();
    }
  }
}

class _StepReport {
  _StepReport(this.step, this.status, [this.message]);

  factory _StepReport.done(String step) => _StepReport(step, 'done');
  factory _StepReport.failed(String step, String message) =>
      _StepReport(step, 'failed', message);
  factory _StepReport.skipped(String step, String reason) =>
      _StepReport(step, 'skipped', reason);

  final String step;
  final String status;
  final String? message;
}

const String _mainDartTemplate = '''
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:finvoras/core/configs/di.dart';
import 'package:finvoras/core/configs/prepare_environment.dart';
import 'package:finvoras/flavors.dart';
import 'package:finvoras/main_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  AppFlavorConfig.flavor = Flavor.values.firstWhere((f) => f.name == appFlavor);
  final shouldEnableAnalytics =
      AppFlavorConfig.flavor == Flavor.qa || AppFlavorConfig.flavor == Flavor.prod;
  await AppAnalytics.instance.bootstrap(
    options: AnalyticsBootstrapOptions(
      enableSentry: shouldEnableAnalytics,
      enableCrashlytics: shouldEnableAnalytics,
      configureSentry: _configureSentry,
    ),
    appRunner: _runApplication,
  );
}

void _configureSentry(SentryFlutterOptions options) {
  options.dsn = AppFlavorConfig.sentryDsn;
  options.tracesSampleRate = AppFlavorConfig.tracesSampleRate;
  options.environment = AppFlavorConfig.flavor.name;
  options.attachStacktrace = true;
  options.attachThreads = true;
  options.sendDefaultPii = true;
  options.enableAutoPerformanceTracing = AppFlavorConfig.isTrackingPerformance;
  options.enableAutoSessionTracking = true;
  options.debug = kDebugMode;
}

Future<void> _runApplication() async {
  ErrorWidget.builder = (_) => const SizedBox.shrink();
  configureDependencies();
  await prepareEnvironment();
  if (AppAnalytics.instance.isSentryEnabled) {
    runApp(SentryWidget(child: const MainApp()));
    return;
  }
  runApp(const MainApp());
}
''';

const String _diTemplate = r'''
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:finvoras/core/configs/di.config.dart';

final getIt = GetIt.instance;

@InjectableInit(initializerName: r'$initGetIt')
void configureDependencies() => $initGetIt(getIt);
''';

const String _prepareEnvironmentTemplate = '''
import 'package:app_core/app_core.dart';
import 'package:app_orchestrator/app_orchestrator.dart';
import 'package:finvoras/core/configs/di.dart';

Future<void> prepareEnvironment() async {
  await AppPathService.instance.init();
  await AppKeyStorage.instance.init(
    pinStorageToken: AppSecrets.keyStoragePinToken,
  );
  await registerAppOrchestratorDependencies(getIt);
}
''';
