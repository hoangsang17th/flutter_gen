import 'dart:io';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

class ProjectService {
  Future<void> updatePubspecYaml(Function(YamlEditor editor) update) async {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) return;

    final content = await file.readAsString();
    final editor = YamlEditor(content);

    update(editor);

    await file.writeAsString(editor.toString());
  }

  Future<void> setupMelosConfig(String appName, List<String> packages) async {
    final file = File('melos.yaml');
    final content = '''
name: $appName
packages:
  - .
${packages.map((p) => '  - $p').join('\n')}
''';
    await file.writeAsString(content);
    print('✅ Created melos.yaml');
  }

  Future<void> updateIosPodfilePlatform(String version) async {
    final file = File('ios/Podfile');
    if (!file.existsSync()) return;

    print('📱 Setting iOS platform to $version in Podfile...');
    final content = await file.readAsString();
    final platformRegex = RegExp(
        r'''^\s*#?\s*platform\s+:ios,\s+['"][^'"]+['"]''',
        multiLine: true);

    if (platformRegex.hasMatch(content)) {
      final newContent =
          content.replaceFirst(platformRegex, "platform :ios, '$version'");
      await file.writeAsString(newContent);
    } else {
      final newContent = "platform :ios, '$version'\n$content";
      await file.writeAsString(newContent);
    }
    print('✅ Updated ios/Podfile');
  }

  Future<void> createDirectories(List<String> paths) async {
    for (final path in paths) {
      await Directory(path).create(recursive: true);
      print('📁 Created directory: $path');
    }
  }

  dynamic readPubspecConfig(List<String> path) {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) return null;
    final doc = loadYaml(file.readAsStringSync());

    dynamic current = doc;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }
}
