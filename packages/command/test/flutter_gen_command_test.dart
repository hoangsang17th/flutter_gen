import 'dart:io' show Platform;

import 'package:flutter_gen_v2_core/version.gen.dart';
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

final separator = Platform.pathSeparator;

void main() {
  test('Execute finvoras_gen', () async {
    final process = await TestProcess.start(
      'dart',
      ['bin/flutter_gen_command.dart'],
    );
    expect(
      await process.stdout.next,
      equals('[FinvorasGen] v$packageVersion Loading ...'),
    );
    await process.shouldExit(0);
  });

  test('Execute finvoras_gen --config pubspec.yaml', () async {
    var process = await TestProcess.start(
      'dart',
      ['bin/flutter_gen_command.dart', '--config', 'pubspec.yaml'],
    );
    expect(
      await process.stdout.next,
      equals('[FinvorasGen] v$packageVersion Loading ...'),
    );
    await process.shouldExit(0);
  });

  test('Execute finvoras_gen --help', () async {
    var process = await TestProcess.start(
      'dart',
      ['bin/flutter_gen_command.dart', '--help'],
    );
    expect(
      await process.stdout.next,
      equals('-c, --config          Set the path of pubspec.yaml.'),
    );
    final line = await process.stdout.next;
    expect(line.trim(), equals('(defaults to "pubspec.yaml")'));
    await process.shouldExit(0);
  });

  test('Execute finvoras_gen --version', () async {
    var process = await TestProcess.start(
      'dart',
      ['bin/flutter_gen_command.dart', '--version'],
    );
    expect(await process.stdout.next, equals('[FinvorasGen] v$packageVersion'));
    await process.shouldExit(0);
  });

  test('Execute wrong arguments with finvoras_gen --wrong', () async {
    var process = await TestProcess.start(
      'dart',
      ['bin/flutter_gen_command.dart', '--wrong'],
    );
    expect(
      await process.stderr.next,
      equals('Could not find an option named "--wrong".'),
    );
    expect(
      await process.stderr.next,
      equals('usage: finvoras_gen [options...]'),
    );
    await process.shouldExit(0);
  });

  test('Execute deprecated config with finvoras_gen', () async {
    final process = await TestProcess.start(
      'dart',
      [
        'bin/flutter_gen_command.dart',
        '--config',
        'test/deprecated_configs.yaml',
      ],
    );
    final errors = (await process.stderr.rest.toList()).join('\n');

    expect(errors, contains('style'));
    expect(errors, contains('package_parameter_enabled'));
    await process.shouldExit(0);
  });
}
