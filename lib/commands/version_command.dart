import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'base_command.dart';

class VersionCommand extends BaseCommand {
  @override
  final name = 'version';

  @override
  final description = 'Check the current version of FinvorasGen.';

  @override
  void run() {
    print('FinvorasGen v${_getVersion()}');
  }

  String _getVersion() {
    try {
      final scriptPath = Platform.script.isScheme('file')
          ? Platform.script.toFilePath()
          : null;

      if (scriptPath != null) {
        var dir = Directory(p.dirname(scriptPath));
        while (dir.path != dir.parent.path) {
          final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
          if (pubspec.existsSync()) {
            final content = pubspec.readAsStringSync();
            final yaml = loadYaml(content);
            if (yaml is Map && yaml['name'] == 'finvoras_gen') {
              return yaml['version']?.toString() ?? 'unknown';
            }
          }
          dir = dir.parent;
        }
      }
    } catch (_) {}
    return 'unknown';
  }
}
