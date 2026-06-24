import 'dart:io';
import 'package:yaml/yaml.dart';

class ProjectSpec {
  ProjectSpec({
    required this.appName,
    required this.appId,
    required this.isMonorepo,
    required this.environments,
    required this.hasFinvorasGenConfig,
  });

  final String appName;
  final String appId;
  final bool isMonorepo;
  final List<String> environments;
  final bool hasFinvorasGenConfig;

  Map<String, dynamic> toMap() {
    return {
      'app_name': appName,
      'app_id': appId,
      'is_monorepo': isMonorepo,
      'environments': environments.map((e) => {'name': e}).toList(),
      'has_finvoras_gen_config': hasFinvorasGenConfig,
    };
  }

  static Future<ProjectSpec> fromPubspec() async {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }

    final content = await pubspecFile.readAsString();
    final doc = loadYaml(content) as YamlMap;
    
    final appName = doc['name'] as String? ?? 'app';
    final finvorasGen = doc['finvoras_gen'] as YamlMap?;
    final appId = finvorasGen?['app_id'] as String? ?? 'com.example.$appName';
    final workspace = doc['workspace'] as YamlList?;
    final isMonorepo = workspace != null && workspace.isNotEmpty;

    // Default environments if none provided
    final environments = ['dev', 'qa', 'prod'];

    return ProjectSpec(
      appName: appName,
      appId: appId,
      isMonorepo: isMonorepo,
      environments: environments,
      hasFinvorasGenConfig: finvorasGen != null,
    );
  }
}
