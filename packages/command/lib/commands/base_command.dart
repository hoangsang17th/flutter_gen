import 'dart:io';
import 'package:args/command_runner.dart';

abstract class BaseCommand extends Command {
  Future<void> runCommand(
    String command,
    List<String> arguments, {
    bool throwOnError = true,
  }) async {
    print('Executing: $command ${arguments.join(' ')}');
    try {
      final result = await Process.run(command, arguments);
      final output = result.stdout.toString().trim();
      final error = result.stderr.toString().trim();

      if (result.exitCode != 0) {
        final errorMessage = StringBuffer();
        errorMessage.writeln(
            '❌ Error executing $command (exit code ${result.exitCode})');
        if (output.isNotEmpty) {
          errorMessage.writeln('STDOUT:\n$output');
        }
        if (error.isNotEmpty) {
          errorMessage.writeln('STDERR:\n$error');
        }

        final msg = errorMessage.toString().trim();
        print(msg);
        if (throwOnError) {
          throw Exception(msg);
        }
      } else {
        if (output.isNotEmpty) {
          print(output);
        }
      }
    } catch (e) {
      final errorMessage = '❌ Failed to start $command: $e';
      print(errorMessage);
      if (throwOnError) {
        rethrow;
      }
    }
  }
}
