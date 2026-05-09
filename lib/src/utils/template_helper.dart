import 'dart:io';

class TemplateHelper {
  static String render(String template, Map<String, dynamic> variables) {
    var result = template;

    // Simple mustache-like rendering
    variables.forEach((key, value) {
      if (value is bool) {
        // Handle sections {{#key}}...{{/key}} and {{^key}}...{{/key}}
        final openTag = '{{#$key}}';
        final closeTag = '{{/$key}}';
        final invertedOpenTag = '{{^$key}}';

        if (value) {
          // Keep content of {{#key}}, remove tags and {{^key}} sections
          result = _processSection(result, openTag, closeTag, true);
          result = _processSection(result, invertedOpenTag, closeTag, false);
        } else {
          // Remove content of {{#key}}, remove tags and keep {{^key}} sections
          result = _processSection(result, openTag, closeTag, false);
          result = _processSection(result, invertedOpenTag, closeTag, true);
        }
      } else if (value is List<Map<String, dynamic>>) {
        // Handle lists {{#key}}...{{/key}}
        final openTag = '{{#$key}}';
        final closeTag = '{{/$key}}';

        final startIndex = result.indexOf(openTag);
        final endIndex = result.indexOf(closeTag);

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final sectionTemplate = result.substring(startIndex + openTag.length, endIndex);
          final renderedList = value.map((item) => render(sectionTemplate, item)).join('');
          result = result.replaceRange(startIndex, endIndex + closeTag.length, renderedList);
        }
      } else {
        // Simple replacement {{key}}
        result = result.replaceAll('{{$key}}', value.toString());
      }
    });

    return result;
  }

  static String _processSection(String text, String openTag, String closeTag, bool keepContent) {
    var result = text;
    while (true) {
      final startIndex = result.indexOf(openTag);
      final endIndex = result.indexOf(closeTag);

      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) break;

      if (keepContent) {
        result = result.replaceRange(endIndex, endIndex + closeTag.length, '');
        result = result.replaceRange(startIndex, startIndex + openTag.length, '');
      } else {
        result = result.replaceRange(startIndex, endIndex + closeTag.length, '');
      }
    }
    return result;
  }

  static Future<String> getTemplate(String path) async {
    // In a real app, these might be assets or embedded strings.
    // For now, we read from the filesystem as we are in the source tree.
    // When distributed, we'd need a different way.
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Template not found: $path');
    }
    return file.readAsString();
  }
}
