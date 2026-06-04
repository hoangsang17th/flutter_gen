// ignore_for_file: unnecessary_raw_strings

const String mainDartTemplate = r"""
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:finvoras/core/configs/di.dart';
import 'package:finvoras/core/configs/prepare_environment.dart';
import 'package:finvoras/flavors.dart';
import 'package:finvoras/main_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  AppFlavorConfig.flavor = Flavor.values.firstWhere((f) => f.name == appFlavor);
  final shouldEnableAnalytics =
      AppFlavorConfig.flavor == Flavor.qa ||
      AppFlavorConfig.flavor == Flavor.prod;
  await AppAnalytics.instance.bootstrap(
    options: AnalyticsBootstrapOptions(
      enableSentry: shouldEnableAnalytics,
      enableCrashlytics: shouldEnableAnalytics,
      configureSentry: _configureSentry,
    ),
    appRunner: _runApplication,
  );
}

void _configureSentry(SentryFlutterOptions options) {
  options.dsn = AppFlavorConfig.sentryDsn;
  options.tracesSampleRate = AppFlavorConfig.tracesSampleRate;
  options.environment = AppFlavorConfig.flavor.name;
  options.attachStacktrace = true;
  options.debug = kDebugMode;
}

Future<void> _runApplication() async {
  ErrorWidget.builder = (_) => const SizedBox.shrink();
  await configureDependencies();
  await prepareCriticalEnvironment();

  if (AppAnalytics.instance.isSentryEnabled) {
    runApp(SentryWidget(child: const MainApp()));
  } else {
    runApp(const MainApp());
  }

  unawaited(prepareDeferredEnvironment());
}
""";
