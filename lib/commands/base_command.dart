import 'dart:io';
import 'package:args/command_runner.dart';

import '../src/services/flutter_service.dart';
import '../src/services/git_service.dart';
import '../src/services/project_service.dart';

abstract class BaseCommand extends Command {
  final flutterService = FlutterService();
  final gitService = GitService();
  final projectService = ProjectService();

  Future<void> runCommand(
    String command,
    List<String> arguments, {
    bool throwOnError = true,
  }) async {
    if (command == 'flutter') {
      await flutterService.run(arguments, throwOnError: throwOnError);
    } else if (command == 'dart') {
      await flutterService.dart(arguments, throwOnError: throwOnError);
    } else {
      print('🚀 Executing: $command ${arguments.join(' ')}');
      final process = await Process.start(
        command,
        arguments,
        runInShell: true,
        mode: ProcessStartMode.inheritStdio,
      );
      final exitCode = await process.exitCode;
      if (exitCode != 0 && throwOnError) {
        throw Exception('Command $command failed with exit code $exitCode');
      }
    }
  }
}
