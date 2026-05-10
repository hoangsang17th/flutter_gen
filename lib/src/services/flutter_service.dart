import 'dart:io';

class FlutterService {
  Future<void> run(List<String> arguments,
      {String? cwd, bool throwOnError = true}) async {
    await _execute('flutter', arguments, cwd: cwd, throwOnError: throwOnError);
  }

  Future<void> dart(List<String> arguments,
      {String? cwd, bool throwOnError = true}) async {
    await _execute('dart', arguments, cwd: cwd, throwOnError: throwOnError);
  }

  Future<void> _execute(String command, List<String> arguments,
      {String? cwd, bool throwOnError = true}) async {
    print('🚀 Executing: $command ${arguments.join(' ')}');

    final process = await Process.start(
      command,
      arguments,
      workingDirectory: cwd,
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      if (throwOnError) {
        throw Exception('Command $command failed with exit code $exitCode');
      }
    }
  }

  Future<void> create(String appName, String org, {String? appId}) async {
    await run([
      'create',
      '--empty',
      '--org',
      org,
      '--project-name',
      appName,
      '.',
    ]);
  }

  Future<void> pubGet({String? cwd}) async {
    await run(['pub', 'get'], cwd: cwd);
  }

  Future<void> addDependencies(List<String> packages, {String? cwd}) async {
    if (packages.isEmpty) return;
    await run(['pub', 'add', ...packages], cwd: cwd);
  }
}
