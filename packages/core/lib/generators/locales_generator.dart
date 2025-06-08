// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:flutter_gen_v2_core/generators/generator_helper.dart';
import 'package:flutter_gen_v2_core/settings/pubspec.dart';
import 'package:flutter_gen_v2_core/utils/error.dart';
import 'package:path/path.dart';

Future<String> generateLocales(
  File pubspecFile,
  FlutterGenLocales config,
  DartFormatter formatter,
) async {
  if (config.folder.isEmpty) {
    throw const InvalidSettingsException(
      'The value of "flutter_gen_v2/locales:" is incorrect.',
    );
  }
  final files = await Directory(config.folder)
      .list(recursive: false)
      .where((entry) => entry.path.endsWith('.json'))
      .toList();

  final maps = <String, Map<String, dynamic>?>{};
  for (final file in files) {
    try {
      final map = jsonDecode(await File(file.path).readAsString());
      final localeKey = basenameWithoutExtension(file.path);
      maps[localeKey] = map as Map<String, dynamic>?;
    } on Exception catch (_) {
      print('Error parsing file: ${file.path}');
      print('Make sure the file is a valid JSON file.');
      rethrow;
    }
  }

  final locales = <String, Map<String, String>>{};
  maps.forEach((key, value) {
    final result = <String, String>{};
    _resolve(value!, result);
    locales[key] = result;
  });
  final keys = <String>{};
  locales.forEach((key, value) {
    value.forEach((key, value) {
      keys.add(key);
    });
  });
  final parsedKeys = keys.map((e) => '\tstatic const $e = \'$e\';').join('\n');

  final parsedLocales = StringBuffer('\n');
  final translationsKeys = StringBuffer();
  locales.forEach((key, value) {
    parsedLocales.writeln('\tstatic const $key = {');
    translationsKeys.writeln('\t\t\'$key\' : _Locales.$key,');
    value.forEach((key, value) {
      value = _replaceValue(value);
      if (RegExp(r'^[0-9]|[!@#<>?":`~;[\]\\|=+)(*&^%-\s]').hasMatch(key)) {
        throw InvalidSettingsException(
          'The key "$key" in the file "$key" is invalid. '
          'Keys must start with a letter and can only contain letters, numbers, and underscores.',
        );
      }
      parsedLocales.writeln('\t\t\'$key\': \'$value\',');
    });
    parsedLocales.writeln('\t};');
  });

  final buffer = StringBuffer();
  final translationName = config.outputs.translationName;
  final keysName = config.outputs.keysName;

  buffer.write('''
$header
$ignore
class $translationName {
  $translationName._();

  \tstatic const Map<String, Map<String, String>> translations = {
  ${translationsKeys.toString()}
  \t};
}

class $keysName {
  $keysName._();

  ${parsedKeys.toString()}
}

class _Locales {
\t${parsedLocales.toString()}
}
''');

  return formatter.format(buffer.toString());
}

void _resolve(
  Map<String, dynamic> localization,
  Map<String, String?> result, [
  String? accKey,
]) {
  final sortedKeys = localization.keys.toList();

  for (final key in sortedKeys) {
    if (localization[key] is Map) {
      var nextAccKey = key;
      if (accKey != null) {
        nextAccKey = '${accKey}_$key';
      }
      _resolve(localization[key] as Map<String, dynamic>, result, nextAccKey);
    } else {
      result[accKey != null ? '${accKey}_$key' : key] =
          localization[key] as String?;
    }
  }
}

String _replaceValue(String value) {
  return value
      // ignore: use_raw_strings
      .replaceAll("'", "\\'")
      // ignore: use_raw_strings
      .replaceAll('\n', '\\n')
      // ignore: use_raw_strings
      .replaceAll('\$', '\\\$');
}
