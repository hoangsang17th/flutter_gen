const String appKeysDartTemplate = r"""
{{#is_monorepo}}
import 'package:app_core/app_core.dart';
{{/is_monorepo}}

class AppKey {
  {{#is_monorepo}}
  static const userName = KeyEnum('user_name');
  static const deviceId = KeyEnum('device_id');
  {{/is_monorepo}}
  {{^is_monorepo}}
  static const String userName = 'user_name';
  static const String deviceId = 'device_id';
  {{/is_monorepo}}
}
""";
