import 'dart:io';
import 'package:finvoras_gen/src/services/project_service.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late ProjectService projectService;
  late Directory tempDir;
  late Directory previousDir;

  setUp(() async {
    projectService = ProjectService();
    tempDir = await Directory.systemTemp.createTemp('project_service_test');
    previousDir = Directory.current;
    Directory.current = tempDir;
  });

  tearDown(() async {
    Directory.current = previousDir;
    await tempDir.delete(recursive: true);
  });

  group('ProjectService', () {
    test('setupMelosConfig should create melos.yaml', () async {
      await projectService.setupMelosConfig('my_app', ['pkg1', 'pkg2']);

      final file = File('melos.yaml');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('name: my_app'));
      expect(content, contains('- .'));
      expect(content, contains('- pkg1'));
      expect(content, contains('- pkg2'));
    });

    test('updatePubspecYaml should modify pubspec.yaml', () async {
      final file = File('pubspec.yaml');
      file.writeAsStringSync('name: old_name\nversion: 1.0.0\n');

      await projectService.updatePubspecYaml((editor) {
        editor.update(['name'], 'new_name');
      });

      final content = file.readAsStringSync();
      final yaml = loadYaml(content);
      expect(yaml['name'], equals('new_name'));
    });

    test('updateIosPodfilePlatform should update platform version', () async {
      final iosDir = Directory('ios')..createSync();
      final podfile = File('ios/Podfile')
        ..writeAsStringSync("platform :ios, '12.0'\ntarget 'Runner' do\nend");

      await projectService.updateIosPodfilePlatform('15.0');

      final content = podfile.readAsStringSync();
      expect(content, contains("platform :ios, '15.0'"));
    });

    test('createDirectories should create multiple directories', () async {
      await projectService.createDirectories(['a/b', 'c/d']);

      expect(Directory('a/b').existsSync(), isTrue);
      expect(Directory('c/d').existsSync(), isTrue);
    });
  });
}
