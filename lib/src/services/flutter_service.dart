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
    final result = await Process.run(command, arguments, workingDirectory: cwd);

    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      print('❌ Error: $error');
      if (throwOnError) {
        throw Exception(
            'Command $command failed with exit code ${result.exitCode}');
      }
    } else {
      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        print(output);
      }
    }
  }

  Future<void> create(String appName, String org, {String? appId}) async {
    await run([
      'create',
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
