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
      multiLine: true,
    );

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

  Future<void> fixIosAppIconName() async {
    final file = File('ios/Runner.xcodeproj/project.pbxproj');
    if (!file.existsSync()) return;

    final content = await file.readAsString();
    if (content.contains(r'$(ASSET_PREFIX)AppIcon')) {
      final newContent = content.replaceAll(
        r'$(ASSET_PREFIX)AppIcon',
        r'AppIcon-$(ASSET_PREFIX)',
      );
      await file.writeAsString(newContent);
      print('✅ Fixed iOS App Icon names in Xcode project');
    }
  }

  Future<void> cleanupDefaultAssets() async {
    final pathsToDelete = [
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      'ios/Runner/Assets.xcassets/LaunchImage.imageset',
    ];

    for (final path in pathsToDelete) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }

    final mipmapDirs = [
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
      'anydpi-v26',
    ];
    for (final dpi in mipmapDirs) {
      final base = 'android/app/src/main/res/mipmap-$dpi';
      final files = [
        'ic_launcher.png',
        'ic_launcher_round.png',
        'ic_launcher.xml',
        'ic_launcher_round.xml',
        'ic_launcher_foreground.xml',
        'ic_launcher_background.xml',
      ];

      for (final file in files) {
        final f = File('$base/$file');
        if (f.existsSync()) {
          await f.delete();
        }
      }
    }
    print('🧹 Cleaned up default OS assets');
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
