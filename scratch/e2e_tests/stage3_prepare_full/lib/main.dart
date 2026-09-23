import 'dart:async';

import 'package:stageone/core/configs/prepare_environment.dart';
import 'package:stageone/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:app_core/app_core.dart';
// TODO: import 'package:stageone/flavors.dart'; if branding is used

Future<void> main() async {
  // TODO: Uncomment when using finvoras_gen branding --type platform
  // AppFlavorConfig.flavor = Flavor.values.firstWhere((f) => f.name == appFlavor);
  // final shouldEnableAnalytics = AppFlavorConfig.flavor == Flavor.qa || AppFlavorConfig.flavor == Flavor.prod;

  ErrorWidget.builder = (_) => const SizedBox.shrink();

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

}


Future<void> _runApplication() async {
  await prepareCriticalEnvironment();
  runApp(const App());
  // TODO: Add your native splash removal logic here
  unawaited(prepareDeferredEnvironment());
}
