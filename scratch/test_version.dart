import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main() {
  final script = Platform.script.toFilePath();
  print('Script path: $script');

  // Find project root (where pubspec.yaml is)
  Directory current = File(script).parent;
  while (current.path != current.parent.path) {
    final pubspec = File(p.join(current.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      print('Found pubspec at: ${pubspec.path}');
      final content = pubspec.readAsStringSync();
      final yaml = loadYaml(content);
      print('Version: ${yaml['version']}');
      return;
    }
    current = current.parent;
  }
  print('Pubspec not found');
}
