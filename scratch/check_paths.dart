import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  print('Script: ${Platform.script}');
  print('Executable: ${Platform.executable}');
  print('Resolved executable: ${Platform.resolvedExecutable}');
}
