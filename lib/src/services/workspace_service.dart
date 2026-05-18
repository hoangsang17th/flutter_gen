import 'dart:io';

import 'package:yaml/yaml.dart';

class WorkspaceService {
  List<String> readWorkspacePackages({String cwd = '.'}) {
    final file = File('$cwd/pubspec.yaml');
    if (!file.existsSync()) return const [];

    final doc = loadYaml(file.readAsStringSync());
    final workspace = doc is Map ? doc['workspace'] : null;
    if (workspace is! List) return const [];

    final packages = <String>[];
    for (final entry in workspace) {
      if (entry is String && entry.trim().isNotEmpty) {
        packages.add(entry.trim());
      }
    }
    return packages;
  }

  bool hasBuildRunner(String cwd) {
    final file = File('$cwd/pubspec.yaml');
    if (!file.existsSync()) return false;
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! Map) return false;
    final devDeps = doc['dev_dependencies'];
    return devDeps is Map && devDeps.containsKey('build_runner');
  }

  bool hasFinvorasGen(String cwd) {
    final file = File('$cwd/pubspec.yaml');
    if (!file.existsSync()) return false;
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! Map) return false;
    return doc.containsKey('finvoras_gen');
  }

  bool isPackageDirectory(String cwd) {
    return File('$cwd/pubspec.yaml').existsSync();
  }

  List<String> selectTargets({
    required String workspaceOption,
    required List<String> workspacePackages,
  }) {
    if (workspaceOption == 'root') return const [];
    if (workspaceOption == 'all') return workspacePackages;

    final requested = workspaceOption
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    return workspacePackages.where(requested.contains).toList();
  }
}
