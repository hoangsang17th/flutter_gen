// ignore_for_file: unnecessary_raw_strings

const String mainDartTemplate = r"""
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:{{app_name}}/core/configs/di.dart';
import 'package:{{app_name}}/core/configs/prepare_environment.dart';
import 'package:{{app_name}}/flavors.dart';
import 'package:{{app_name}}/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
{{#enable_sentry}}
import 'package:sentry_flutter/sentry_flutter.dart';
{{/enable_sentry}}

Future<void> main() async {
  AppFlavorConfig.flavor = Flavor.values.firstWhere((f) => f.name == appFlavor);
  final shouldEnableAnalytics =
      AppFlavorConfig.flavor == Flavor.qa ||
      AppFlavorConfig.flavor == Flavor.prod;
  await AppAnalytics.instance.bootstrap(
    options: AnalyticsBootstrapOptions(
      {{#enable_sentry}}
      enableSentry: shouldEnableAnalytics,
      configureSentry: _configureSentry,
      {{/enable_sentry}}
      enableCrashlytics: shouldEnableAnalytics,
    ),
    appRunner: _runApplication,
  );
}

{{#enable_sentry}}
void _configureSentry(SentryFlutterOptions options) {
  options.dsn = AppFlavorConfig.sentryDsn;
  options.tracesSampleRate = AppFlavorConfig.tracesSampleRate;
  options.environment = AppFlavorConfig.flavor.name;
  options.attachStacktrace = true;
  options.debug = kDebugMode;
}
{{/enable_sentry}}

Future<void> _runApplication() async {
  ErrorWidget.builder = (_) => const SizedBox.shrink();
  await configureDependencies();
  await prepareCriticalEnvironment();

  {{#enable_sentry}}
  if (AppAnalytics.instance.isSentryEnabled) {
    runApp(SentryWidget(child: const App()));
  } else {
    runApp(const App());
  }
  {{/enable_sentry}}
  {{^enable_sentry}}
  runApp(const App());
  {{/enable_sentry}}

  unawaited(prepareDeferredEnvironment());
}
""";
