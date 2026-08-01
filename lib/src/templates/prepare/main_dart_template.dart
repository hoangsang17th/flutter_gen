// ignore_for_file: unnecessary_raw_strings

const String mainDartTemplate = r"""
import 'dart:async';

import 'package:{{app_name}}/core/configs/prepare_environment.dart';
import 'package:{{app_name}}/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

{{#is_monorepo}}
import 'package:app_core/app_core.dart';
// TODO: import 'package:{{app_name}}/flavors.dart'; if branding is used
{{/is_monorepo}}

Future<void> main() async {
  // TODO: Uncomment when using finvoras_gen branding --type platform
  // AppFlavorConfig.flavor = Flavor.values.firstWhere((f) => f.name == appFlavor);
  // final shouldEnableAnalytics = AppFlavorConfig.flavor == Flavor.qa || AppFlavorConfig.flavor == Flavor.prod;

  ErrorWidget.builder = (_) => const SizedBox.shrink();

  {{#is_monorepo}}
  await AppAnalytics.instance.bootstrap(
    options: const AnalyticsBootstrapOptions(
      // TODO: Replace with shouldEnableAnalytics when flavors are ready
      enableCrashlytics: kReleaseMode,
      enableFirebaseAnalytics: kReleaseMode,
      crashlytics: CrashlyticsIntegrationOptions(enableInDebug: kDebugMode),
      firebaseAnalytics: AnalyticsIntegrationOptions(enableInDebug: kDebugMode),
    ),
    appRunner: _runApplication,
  );
  {{/is_monorepo}}

  {{^is_monorepo}}
  await _runApplication();
  {{/is_monorepo}}
}


Future<void> _runApplication() async {
  await prepareCriticalEnvironment();
  runApp(const App());
  // TODO: Add your native splash removal logic here
  unawaited(prepareDeferredEnvironment());
}
""";
