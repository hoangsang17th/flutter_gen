// ignore_for_file: unnecessary_raw_strings

const String prepareEnvironmentDartTemplate = r"""
import 'dart:async';

{{#is_monorepo}}
import 'package:app_bootstrap/app_bootstrap.dart';
import 'package:app_core/app_core.dart';
import 'package:app_orchestrator/app_orchestrator.dart';
import 'package:app_shell_utils/app_shell_utils.dart';
{{/is_monorepo}}
import 'package:{{app_name}}/core/configs/di.dart';
import 'package:{{app_name}}/core/configs/app_keys.dart';
import 'package:{{app_name}}/generated/locales.gen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

Future<void> prepareCriticalEnvironment() async {
  WidgetsBinding? widgetsBinding;

  final pipeline = BootstrapPipeline(
    steps: [
      // Phase 1: Ensure Flutter binding & Native splash
      BootstrapStep(
        name: 'Ensure Flutter binding',
        shouldRun: () => widgetsBinding == null,
        run: () async {
          widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
        },
      ),
      BootstrapStep(
        name: 'Register debug frame timings',
        run: () async => _registerDebugFrameTimings(),
      ),
      BootstrapStep(
        name: 'Preserve native splash',
        run: () async {
          // TODO: Add your native splash preservation logic here
        },
      ),

      // Phase 2: Foundation & Storage
      BootstrapStep(
        name: 'Prepare foundation',
        run: _prepareFoundation,
      ),
      BootstrapStep(
        name: 'Initialize storage',
        run: _prepareStorage,
      ),

      // Phase 3: Dependencies & Core Services
      BootstrapStep(
        name: 'Register dependencies',
        run: _registerDependencies,
      ),
      BootstrapStep(
        name: 'Prepare core services',
        run: _prepareCoreServices,
      ),

      // Phase 4: Utilities & Platform
      BootstrapStep(
        name: 'Register HTTP localizations',
        run: () async => _registerHttpLocalizationResolver(),
      ),
      BootstrapStep(
        name: 'Configure platform',
        run: _preparePlatformEnvironment,
      ),
    ],
  );

  try {
    await pipeline.run();
  } catch (exception, stackTrace) {
    {{#is_monorepo}}
    await AppSentryService.instance.reportError(exception, stackTrace);
    {{/is_monorepo}}
    rethrow;
  }
}

Future<void> prepareDeferredEnvironment() async {
  final pipeline = BootstrapPipeline(
    steps: [
      BootstrapStep(
        name: 'Wait for first frame',
        run: _waitForFirstFrame,
      ),
      {{#is_monorepo}}
      BootstrapStep(
        name: 'Initialize app actions & event bus',
        run: () async {
          AppActions.instance.init();
          AppEventBusService.instance.init();
        },
      ),
      // Phase 7: Shared runtime services (parallel)
      ParallelBootstrapStep(
        name: 'Initialize shared runtime services',
        steps: [
          BootstrapStep(
            name: 'App links',
            run: _initializeAppLinks,
          ),
          BootstrapStep(
            name: 'Crashlytics',
            run: AppAnalytics.instance.ensureCrashlyticsInitialized,
          ),
          BootstrapStep(
            name: 'Firebase Analytics',
            run: AppAnalytics.instance.ensureFirebaseAnalyticsInitialized,
          ),
          BootstrapStep(
            name: 'Remote config',
            run: () async {
              await AppRemoteConfig.instance.init(
                minimumFetchInterval: const Duration(hours: 4),
                extendedDefaults: {},
              );
            },
          ),
        ],
      ),
      BootstrapStep(
        name: 'Initialize lifecycle',
        run: () async {
          AppLifecycle.instance.init();
          // AppLifecycle.instance.onSuspending(() async {});
          // AppLifecycle.instance.onResumed(() async {});
        },
      ),
      {{/is_monorepo}}
    ],
  );

  try {
    await pipeline.run();
  } catch (e) {
    {{#is_monorepo}}
    AppLogger.error(
      'Deferred environment initialization error',
      AppLoggingType.OTHER,
      e,
    );
    {{/is_monorepo}}
  }
}

void _registerDebugFrameTimings() {
  if (!kDebugMode) {
    return;
  }
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMilliseconds;
      final rasterMs = timing.rasterDuration.inMilliseconds;
      if (buildMs > 16 || rasterMs > 16) {
        {{#is_monorepo}}
        AppLogger.warning(
          'Jank frame: build=${buildMs}ms raster=${rasterMs}ms',
          AppLoggingType.OTHER,
        );
        {{/is_monorepo}}
      }
    }
  });
}

Future<void> _prepareFoundation() {
  return SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
  );
}

Future<void> _prepareStorage() async {
  {{#is_monorepo}}
  await AppPathService.instance.init();
  await AppKeyStorage.instance.init(
    keyObjects: [
      KeyObject(key: AppKey.userName),
      KeyObject(key: AppKey.deviceId),
      // TODO: Add more keys here
    ],
  );
  {{/is_monorepo}}
}

Future<void> _registerDependencies() async {
  {{#is_monorepo}}
  await registerAppOrchestratorDependencies(
    getIt,
    storage: AppKeyStorage.instance,
    translations: AppTranslation.translations,
  );
  {{/is_monorepo}}
  await configureDependencies();

  {{#is_monorepo}}
  registerAppNavigatorDelegate();
  // TODO: AppLinksService.instance.registerKnownRoutes(AppRoutes.all);
  {{/is_monorepo}}
}

Future<void> _prepareCoreServices() {
  return Firebase.initializeApp(
    options: null, // TODO: Replace with DefaultFirebaseOptions.currentPlatform
  );
}

void _registerHttpLocalizationResolver() {
  {{#is_monorepo}}
  AppHttpLocalizations.register((key, {params = const {}}) {
    final controller = AppOrchestraController.instance;
    final locale = controller.locale ?? controller.fallbackLocale;
    final translations = controller.translations;

    final template =
        translations[locale.toString()]?[key] ??
        translations[locale.languageCode]?[key];
    if (template == null || template.isEmpty) {
      return null;
    }

    var formatted = template;
    params.forEach((paramKey, paramValue) {
      formatted = formatted.replaceAll('@$paramKey', paramValue);
    });
    return formatted;
  });
  {{/is_monorepo}}
}

Future<void> _preparePlatformEnvironment() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

Future<void> _initializeAppLinks() async {
  {{#is_monorepo}}
  // TODO: Implement AppLinksService initialization
  {{/is_monorepo}}
}

Future<void> _waitForFirstFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  return completer.future;
}
""";
