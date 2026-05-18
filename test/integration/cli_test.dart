import 'dart:io';
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

void main() {
  group('CLI Integration', () {
    test('should show version', () async {
      final process = await TestProcess.start(
        'dart',
        ['bin/flutter_gen_command.dart', 'version'],
      );

      final line = await process.stdout.next;
      expect(line, startsWith('FinvorasGen v'));
      await process.shouldExit(0);
    });

    test('should show help message when run with no arguments', () async {
      final process = await TestProcess.start(
        'dart',
        ['bin/flutter_gen_command.dart'],
      );

      await expectLater(process.stdout, emits('FinvorasGen CLI tool'));
      await expectLater(process.stdout, emits(''));
      await expectLater(
          process.stdout, emits('Usage: finvoras_gen <command> [arguments]'));

      await process.kill();
    });

    test('should show help message for init command', () async {
      final process = await TestProcess.start(
        'dart',
        ['bin/flutter_gen_command.dart', 'init', '--help'],
      );

      await expectLater(
          process.stdout,
          emitsThrough(
              'Initialize a new Flutter project with core packages and submodules.'));

      await process.kill();
    });
  });
}
