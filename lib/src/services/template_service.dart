import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;

class TemplateService {
  /// Reads a template from lib/src/templates/[name].txt
  Future<String> readTemplate(String name) async {
    // 1. Try to find the template via package URI (most robust)
    try {
      final packageUri = Uri.parse('package:finvoras_gen/src/templates/$name.txt');
      final resolvedUri = await Isolate.resolvePackageUri(packageUri);
      if (resolvedUri != null) {
        final file = File.fromUri(resolvedUri);
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
    } catch (_) {
      // Ignore and try other methods
    }

    // 2. Try to find relative to the script location (fallback for local development)
    try {
      final scriptPath = Platform.script.toFilePath();
      final packageRoot = p.dirname(p.dirname(scriptPath)); // assuming bin/script.dart -> root
      final relativePath = p.join(packageRoot, 'lib', 'src', 'templates', '$name.txt');
      final file = File(relativePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}

    // 3. Fallback to current directory (least preferred but kept for legacy)
    final fallbackPath = p.join(Directory.current.path, 'lib', 'src', 'templates', '$name.txt');
    final fallbackFile = File(fallbackPath);
    if (await fallbackFile.exists()) {
      return await fallbackFile.readAsString();
    }

    throw Exception(
        'Template not found: $name. \n'
        'Please ensure the template exists in the package lib/src/templates/ directory.');
  }

  String replace(String template, Map<String, String> values) {
    var result = template;
    values.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    return result;
  }
}
