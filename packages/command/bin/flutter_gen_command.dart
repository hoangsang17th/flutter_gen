import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:finvoras_gen/commands/assets_command.dart';
import 'package:finvoras_gen/commands/init_command.dart';
import 'package:finvoras_gen_core/version.gen.dart';

void main(List<String> args) async {
  final runner = CommandRunner('finvoras_gen', 'FinvorasGen CLI tool')
    ..addCommand(AssetsCommand())
    ..addCommand(InitCommand());

  runner.argParser.addFlag(
    'version',
    abbr: 'v',
    help: 'FinvorasGen version',
    negatable: false,
    callback: (version) {
      if (version) {
        stdout.writeln('[FinvorasGen] v$packageVersion');
        exit(0);
      }
    },
  );

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

