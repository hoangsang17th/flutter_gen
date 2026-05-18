import 'dart:io';

import 'package:finvoras_gen/src/services/workspace_service.dart';
import 'package:test/test.dart';

void main() {
  late WorkspaceService service;
  late Directory tempDir;

  setUp(() async {
    service = WorkspaceService();
    tempDir = await Directory.systemTemp.createTemp('workspace_service_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('readWorkspacePackages parses workspace list from pubspec', () {
    File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: sample
workspace:
  - packages/a
  - packages/b
''');
    expect(
      service.readWorkspacePackages(cwd: tempDir.path),
      ['packages/a', 'packages/b'],
    );
  });

  test('selectTargets supports all, root, and csv selection', () {
    const workspace = ['packages/a', 'packages/b', 'packages/c'];
    expect(
      service.selectTargets(
          workspaceOption: 'all', workspacePackages: workspace),
      workspace,
    );
    expect(
      service.selectTargets(
        workspaceOption: 'root',
        workspacePackages: workspace,
      ),
      isEmpty,
    );
    expect(
      service.selectTargets(
        workspaceOption: 'packages/b,packages/c',
        workspacePackages: workspace,
      ),
      ['packages/b', 'packages/c'],
    );
  });

  test('hasBuildRunner and hasFinvorasGen detect package capabilities', () {
    Directory('${tempDir.path}/packages/a').createSync(recursive: true);
    File('${tempDir.path}/packages/a/pubspec.yaml').writeAsStringSync('''
name: a
dev_dependencies:
  build_runner: ^2.0.0
finvoras_gen:
  output: lib/generated/
''');
    expect(service.hasBuildRunner('${tempDir.path}/packages/a'), isTrue);
    expect(service.hasFinvorasGen('${tempDir.path}/packages/a'), isTrue);
  });
}
