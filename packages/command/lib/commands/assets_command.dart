import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:finvoras_gen_core/flutter_generator.dart';
import 'package:finvoras_gen_core/utils/cast.dart';
import 'package:finvoras_gen_core/utils/error.dart';

class AssetsCommand extends Command {
  @override
  final name = 'assets';

  @override
  final description = 'Generate assets, fonts, and colors.';

  AssetsCommand() {
    argParser.addOption(
      'config',
      abbr: 'c',
      help: 'Set the path of pubspec.yaml.',
      defaultsTo: 'pubspec.yaml',
    );

    argParser.addOption(
      'build',
      abbr: 'b',
      help: 'Set the path of build.yaml.',
    );
  }

  @override
  void run() async {
    final pubspecPath = safeCast<String>(argResults?['config']);
    if (pubspecPath == null || pubspecPath.trim().isEmpty) {
      throw ArgumentError('Invalid value $pubspecPath', 'config');
    }
    final pubspecFile = File(pubspecPath).absolute;

    final buildPath = safeCast<String>(argResults?['build'])?.trim();
    if (buildPath?.isEmpty ?? false) {
      throw ArgumentError('Invalid value $buildPath', 'build');
    }
    final buildFile = buildPath == null ? null : File(buildPath).absolute;

    try {
      await FlutterGenerator(pubspecFile, buildFile: buildFile).build();
    } on InvalidSettingsException catch (e) {
      stderr.write(e.message);
    }
  }
}
