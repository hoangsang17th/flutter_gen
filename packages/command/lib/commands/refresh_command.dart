import 'dart:io';
import 'package:args/command_runner.dart';

class RefreshCommand extends Command {
  @override
  final name = 'refresh';

  @override
  final description = 'Clean the project and fetch dependencies (flutter clean & flutter pub get).';

  @override
  void run() async {
    print('🧹 Cleaning project...');
    await _runCommand('flutter', ['clean']);

    print('\n📦 Fetching dependencies...');
    await _runCommand('flutter', ['pub', 'get']);

    print('\n✅ Project refreshed successfully!');
  }

  Future<void> _runCommand(String command, List<String> arguments) async {
    print('Executing: $command ${arguments.join(' ')}');
    final result = await Process.run(command, arguments);
    if (result.exitCode != 0) {
      print('Error executing $command: ${result.stderr}');
    } else {
      print(result.stdout);
    }
  }
}
