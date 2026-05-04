import 'package:finvoras_gen/src/version/version.gen.dart';
import 'base_command.dart';

class VersionCommand extends BaseCommand {
  @override
  final name = 'version';

  @override
  final description = 'Check the current version of FinvorasGen.';

  @override
  void run() {
    print('FinvorasGen v$packageVersion');
  }
}
