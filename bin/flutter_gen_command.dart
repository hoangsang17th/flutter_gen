import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:finvoras_gen/commands/assets_command.dart';
import 'package:finvoras_gen/commands/branding_command.dart';
import 'package:finvoras_gen/commands/fastlane_command.dart';
import 'package:finvoras_gen/commands/init_command.dart';
import 'package:finvoras_gen/commands/prepare_command.dart';
import 'package:finvoras_gen/commands/refresh_command.dart';
import 'package:finvoras_gen/commands/version_command.dart';

void main(List<String> args) async {
  final runner = CommandRunner('finvoras_gen', 'FinvorasGen CLI tool')
    ..addCommand(AssetsCommand())
    ..addCommand(InitCommand())
    ..addCommand(BrandingCommand())
    ..addCommand(RefreshCommand())
    ..addCommand(PrepareCommand())
    ..addCommand(FastlaneCommand())
    ..addCommand(VersionCommand());

  try {
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
