import 'dart:io';

import 'package:finvoras_gen/src/models/project_spec.dart';
import 'package:finvoras_gen/src/services/flutter_service.dart';
import 'package:finvoras_gen/src/templates/prepare/di_dart_template.dart';
import 'package:finvoras_gen/src/templates/prepare/main_dart_template.dart';
import 'package:finvoras_gen/src/templates/prepare/prepare_environment_dart_template.dart';
import 'package:finvoras_gen/src/templates/prepare/app_dart_template.dart';

import 'base_command.dart';

class PrepareCommand extends BaseCommand {
  PrepareCommand() {
    argParser
      ..addOption(
        'runtime',
        abbr: 'r',
        allowed: ['flutter', 'fvm'],
        mandatory: true,
        help: 'Flutter runtime to use (flutter or fvm).',
      )
      ..addOption(
        'workspace',
        abbr: 'w',
        defaultsTo: 'all',
        help: 'Workspace target: all | root | packages/a,packages/b',
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
      'Bootstrap a finvoras monorepo workspace: sync deps, run codegen, and scaffold core files.';

  @override
  Future<void> run() async {
    final report = <_StepReport>[];

    try {
      await _execute(report);
      _printSummary(report);
      logSuccess('Project prepared successfully.');
    } catch (e) {
      _printSummary(report);
      logError('Preparation failed: $e');
      exit(1);
    }
  }

  Future<void> _execute(List<_StepReport> report) async {
    // Validate project root
    if (!File('pubspec.yaml').existsSync()) {
      throw Exception(
        'pubspec.yaml not found. Run this command from the project root.',
      );
    }

    // Configure runtime
    final runtimeArg = argResults!['runtime'] as String;
    flutterService.setRuntime(
      runtimeArg == 'fvm' ? FlutterRuntime.fvm : FlutterRuntime.flutter,
    );

    final workspaceOption = argResults!['workspace'] as String;

    // Step 1: Scaffold core files
    await _trackStep(report, 'scaffold:core_files', _scaffoldCoreFiles);

    // Step 2: Normalize pubspec.yaml
    await _trackStep(report, 'scaffold:pubspec', _normalizePubspecForMonorepo);

    // Step 3: pub get root
    await _trackStep(report, 'root:pub_get', () async {
      await flutterService.pubGet();
    });

    // Step 4 & 5: pub get + codegen per package
    final workspacePackages = workspaceService.readWorkspacePackages();
    final selectedPackages = workspaceService.selectTargets(
      workspaceOption: workspaceOption,
      workspacePackages: workspacePackages,
    );

    for (final pkg in selectedPackages) {
      await _trackStep(report, '$pkg:pub_get', () async {
        if (!workspaceService.isPackageDirectory(pkg)) {
          throw Exception('Missing package directory: $pkg');
        }
        await flutterService.pubGet(cwd: pkg);
      });
    }

    for (final pkg in selectedPackages) {
      if (!workspaceService.isPackageDirectory(pkg)) {
        report.add(_StepReport.skipped('$pkg:codegen', 'missing directory'));
        continue;
      }
      await _runCodegen(report, pkg);
    }

    // Step 6: codegen root
    await _runCodegen(report, '.');

    // Step 7: verify
    await _trackStep(
      report,
      'verify',
      () async => _verifyScaffoldFiles(),
      continueOnFailure: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Scaffold
  // ---------------------------------------------------------------------------

  Future<void> _scaffoldCoreFiles() async {
    final spec = await ProjectSpec.fromPubspec();
    final data = spec.toMap();

    await projectService.createDirectories(['lib/core/configs/bootstrap']);

    final mainContent = templateService.replace(mainDartTemplate, data);
    await File('lib/main.dart').writeAsString(mainContent);

    final diContent = templateService.replace(diDartTemplate, data);
    await File('lib/core/configs/di.dart').writeAsString(diContent);

    final prepareContent = templateService.replace(prepareEnvironmentDartTemplate, data);
    await File('lib/core/configs/prepare_environment.dart').writeAsString(prepareContent);

    final appContent = templateService.replace(appDartTemplate, data);
    await File('lib/app.dart').writeAsString(appContent);

    logInfo('Scaffolded: main.dart, app.dart, di.dart, prepare_environment.dart');
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

      editor.update(['finvoras_gen'], {
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
                'melos exec --concurrency=1 --dir-exists=assets -- "flutter pub get && if grep -q \\"build_runner\\" pubspec.yaml; then flutter pub run build_runner build --delete-conflicting-outputs; else echo \'Skipping build_runner\'; fi && finvoras_gen -c pubspec.yaml"',
            'description': 'Generate assets code',
          },
        }
      });
    });

    logInfo('Normalized pubspec.yaml for monorepo');
  }

  // ---------------------------------------------------------------------------
  // Codegen
  // ---------------------------------------------------------------------------

  Future<void> _runCodegen(List<_StepReport> report, String cwd) async {
    final label = cwd == '.' ? 'root' : cwd; // ignore: unnecessary_string_interpolations

    if (workspaceService.hasBuildRunner(cwd)) {
      await _trackStep(
        report,
        '$label:build_runner',
        () => flutterService.runBuildRunner(cwd: cwd == '.' ? null : cwd),
        continueOnFailure: true,
      );
    } else {
      report.add(_StepReport.skipped('$label:build_runner', 'no build_runner'));
    }

    if (workspaceService.hasFinvorasGen(cwd)) {
      await _trackStep(
        report,
        '$label:finvoras_assets',
        () => flutterService.runFinvorasAssets(cwd: cwd == '.' ? null : cwd),
        continueOnFailure: true,
      );
    } else {
      report.add(
        _StepReport.skipped('$label:finvoras_assets', 'no finvoras_gen'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Verify
  // ---------------------------------------------------------------------------

  void _verifyScaffoldFiles() {
    const required = [
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

  // ---------------------------------------------------------------------------
  // Reporting
  // ---------------------------------------------------------------------------

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
    const width = 50;
    print('\n${'=' * width}');
    print('  Prepare Summary');
    print('=' * width);
    for (final item in reports) {
      final icon = switch (item.status) {
        'done' => '✅',
        'failed' => '❌',
        _ => '⏭️ ',
      };
      final suffix = item.message != null ? '  (${item.message})' : '';
      print('$icon  ${item.step}$suffix');
    }
    print('${'=' * width}\n');
  }
}

// ---------------------------------------------------------------------------
// Internal model
// ---------------------------------------------------------------------------

class _StepReport {
  const _StepReport(this.step, this.status, [this.message]);

  factory _StepReport.done(String step) => _StepReport(step, 'done');
  factory _StepReport.failed(String step, String message) =>
      _StepReport(step, 'failed', message);
  factory _StepReport.skipped(String step, String reason) =>
      _StepReport(step, 'skipped', reason);

  final String step;
  final String status;
  final String? message;
}
