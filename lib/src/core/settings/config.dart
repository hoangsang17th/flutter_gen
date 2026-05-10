import 'dart:io';

import 'package:finvoras_gen/src/core/settings/config_default.dart';
import 'package:finvoras_gen/src/core/settings/pubspec.dart';
import 'package:finvoras_gen/src/core/utils/error.dart';
import 'package:finvoras_gen/src/core/utils/map.dart';
import 'package:finvoras_gen/src/version/version.gen.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

class Config {
  const Config._({required this.pubspec, required this.pubspecFile});

  final Pubspec pubspec;
  final File pubspecFile;
}

Config loadPubspecConfig(File pubspecFile, {File? buildFile}) {
  final pubspecLocaleHint = normalize(
    join(basename(pubspecFile.parent.path), basename(pubspecFile.path)),
  );

  stdout.writeln('[FinvorasGen] v$packageVersion Loading ...');

  final defaultMap = loadYaml(configDefaultYamlContent) as Map?;

  final pubspecContent = pubspecFile.readAsStringSync();
  final pubspecMap = loadYaml(pubspecContent) as Map?;

  var mergedMap = mergeMap([defaultMap, pubspecMap]);
  stdout.writeln('[FinvorasGen] Reading options from $pubspecLocaleHint');

  YamlMap? getBuildFileOptions(File file) {
    if (!file.existsSync()) {
      return null;
    }
    final buildContent = file.readAsStringSync();
    final rawMap = loadYaml(buildContent) as Map?;
    final builders = rawMap?['targets']?[r'$default']?['builders'];
    final optionBuildMap = (builders?['finvoras_gen_runner'] ??
        builders?['finvoras_gen'])?['options'];
    if (optionBuildMap is YamlMap && optionBuildMap.isNotEmpty) {
      return optionBuildMap;
    }
    return null;
  }

  // Fallback to the build.yaml when no build file has been specified and
  // the default one has valid configurations.
  if (buildFile == null && getBuildFileOptions(File('build.yaml')) != null) {
    buildFile = File('build.yaml');
  }

  if (buildFile != null) {
    if (buildFile.existsSync()) {
      final optionBuildMap = getBuildFileOptions(buildFile);
      if (optionBuildMap != null) {
        final buildMap = {'finvoras_gen': optionBuildMap};
        mergedMap = mergeMap([mergedMap, buildMap]);
        final buildLocaleHint = normalize(
          join(basename(buildFile.parent.path), basename(buildFile.path)),
        );
        stdout.writeln('[FinvorasGen] Reading options from $buildLocaleHint');
      } else {
        stderr.writeln(
          '[FinvorasGen] Specified ${buildFile.path} as input but the file '
          'does not contain valid options, ignoring...',
        );
      }
    } else {
      stderr.writeln(
        '[FinvorasGen] Specified ${buildFile.path} as input but the file '
        'does not exists.',
      );
    }
  }

  final pubspec = Pubspec.fromJson(mergedMap);
  return Config._(pubspec: pubspec, pubspecFile: pubspecFile);
}

Config? loadPubspecConfigOrNull(File pubspecFile, {File? buildFile}) {
  try {
    return loadPubspecConfig(pubspecFile, buildFile: buildFile);
  } on FileSystemException catch (e) {
    stderr.writeln(e.message);
  } on InvalidSettingsException catch (e) {
    stderr.writeln(e.message);
  }
  return null;
}
