import 'dart:io';

class GitService {
  Future<void> clone(
    String url,
    String path, {
    bool recurseSubmodules = true,
  }) async {
    final args = ['clone'];
    if (recurseSubmodules) {
      args.add('--recurse-submodules');
    }
    args.addAll([url, path]);

    print('📦 Cloning $url into $path...');
    final result = await Process.run('git', args);

    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      throw Exception('Git clone failed: $error');
    }
    print('✅ Clone completed.');
  }

  bool isDirectoryGitRepo(String path) {
    return Directory('$path/.git').existsSync();
  }
}
