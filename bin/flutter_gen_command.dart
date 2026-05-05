import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:finvoras_gen/commands/assets_command.dart';
import 'package:finvoras_gen/commands/init_command.dart';
import 'package:finvoras_gen/commands/branding_command.dart';
import 'package:finvoras_gen/commands/prepare_command.dart';
import 'package:finvoras_gen/commands/refresh_command.dart';
import 'package:finvoras_gen/commands/version_command.dart';
import 'package:finvoras_gen/commands/fastlane_command.dart';
import 'package:finvoras_gen/src/version/version.gen.dart';

void main(List<String> args) async {
  final runner = CommandRunner('finvoras_gen', 'FinvorasGen CLI tool')
    ..addCommand(AssetsCommand())
    ..addCommand(InitCommand())
    ..addCommand(BrandingCommand())
    ..addCommand(RefreshCommand())
    ..addCommand(PrepareCommand())
    ..addCommand(FastlaneCommand())
    ..addCommand(VersionCommand());

  runner.argParser.addFlag(
    'version',
    abbr: 'v',
    help: 'FinvorasGen version',
    negatable: false,
  );

  try {
    final results = runner.argParser.parse(args);
    if (results['version'] == true) {
      stdout.writeln('FinvorasGen v$packageVersion');
      exit(0);
    }

    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(runner.usage);
    exit(64);
  } catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}
