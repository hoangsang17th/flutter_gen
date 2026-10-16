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
      Directory('ios').createSync();
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

    test('setupVscodeLaunchConfig should generate default launch.json', () async {
      await projectService.setupVscodeLaunchConfig(appName: 'TestApp');

      final file = File('.vscode/launch.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('TestApp (Debug)'));
      expect(content, contains('TestApp (Profile)'));
      expect(content, contains('TestApp (Release)'));
      expect(content, contains('"program": "lib/main.dart"'));
    });

    test('setupVscodeLaunchConfig should generate flavored launch.json for environments', () async {
      await projectService.setupVscodeLaunchConfig(
        appName: 'TestApp',
        environments: ['dev', 'prod'],
        force: true,
      );

      final file = File('.vscode/launch.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('dev Debug'));
      expect(content, contains('prod Debug'));
      expect(content, contains('"program": "lib/main_dev.dart"'));
      expect(content, contains('"program": "lib/main_prod.dart"'));
    });

    test('setupVscodeSettings should generate settings.json', () async {
      await projectService.setupVscodeSettings();

      final file = File('.vscode/settings.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('dart.analysisExcludedFolders'));
      expect(content, contains('build'));
    });
  });
}
