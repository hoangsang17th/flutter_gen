// ignore_for_file: unnecessary_raw_strings

const String prepareEnvironmentDartTemplate = r"""
import 'dart:async';

{{#is_monorepo}}
import 'package:app_bootstrap/app_bootstrap.dart';
import 'package:app_core/app_core.dart';
import 'package:app_orchestrator/app_orchestrator.dart';
{{/is_monorepo}}
import 'package:{{app_name}}/core/configs/di.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// ---------------------------------------------------------------------------
// Critical — phải hoàn tất trước runApp()
// ---------------------------------------------------------------------------
Future<void> prepareCriticalEnvironment() async {
  WidgetsBinding? widgetsBinding;

  final pipeline = BootstrapPipeline(
    steps: [
      // Phase 1: Foundation
      BootstrapStep(
        name: 'Ensure Flutter binding',
        shouldRun: () => widgetsBinding == null,
        run: () async {
          widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
        },
      ),
      BootstrapStep(
        name: 'Configure system UI',
        run: () async {
          final binding = widgetsBinding;
          if (binding != null) {
            FlutterNativeSplash.preserve(widgetsBinding: binding);
          }
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
          );
        },
      ),

      // Phase 2: Storage
      BootstrapStep(
        name: 'Initialize storage',
        run: () async {
          await AppPathService.instance.init();
          await AppKeyStorage.instance.init(
            pinStorageToken: AppSecrets.keyStoragePinToken,
          );
        },
      ),

      // Phase 3: Dependency registration
      BootstrapStep(
        name: 'Register dependencies',
        run: () async {
          await registerAppOrchestratorDependencies(
            getIt,
            storage: AppKeyStorage.instance,
            translations: AppTranslation.translations,
          );
          // TODO: AppNavigationBinding.registerDelegate(GetXNavigationDelegate());
          // TODO: registerAppNavigatorRoutes();
        },
      ),

      // Phase 4: Core services (parallel)
      ParallelBootstrapStep(
        name: 'Initialize core services',
        steps: [
          BootstrapStep(
            name: 'HTTP client',
            run: () async {
              // TODO: await AppHttpConnect.instance.init(...)
            },
          ),
          BootstrapStep(
            name: 'Firebase',
            run: () async {
              await Firebase.initializeApp(
                options: AppFlavorConfig.firebaseOptions,
              );
            },
          ),
          BootstrapStep(
            name: 'Network checker',
            run: () async {
              // TODO: await AppNetworkChecker.instance.init(...)
            },
          ),
        ],
      ),

      // Phase 5: HTTP i18n resolver
      BootstrapStep(
        name: 'Register HTTP localizations',
        run: () async {
          AppHttpLocalizations.register((key, {params = const {}}) {
            final controller = AppOrchestraController.instance;
            final locale = controller.locale ?? controller.fallbackLocale;
            final template =
                controller.translations[locale.toString()]?[key] ??
                controller.translations[locale.languageCode]?[key];
            if (template == null || template.isEmpty) return null;
            var formatted = template;
            params.forEach((k, v) => formatted = formatted.replaceAll('@$k', v));
            return formatted;
          });
        },
      ),

      // Phase 6: Platform setup
      BootstrapStep(
        name: 'Configure platform',
        run: () async {
          if (isMobile) {
            await SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
            // TODO: await FlutterDisplayMode.setHighRefreshRate();
          }
        },
      ),
    ],
  );

  await pipeline.run();
}

// ---------------------------------------------------------------------------
// Deferred — chạy sau runApp(), không block startup
// ---------------------------------------------------------------------------
Future<void> prepareDeferredEnvironment() async {
  final pipeline = BootstrapPipeline(
    steps: [
      // Phase 7a: Shared runtime services (parallel)
      ParallelBootstrapStep(
        name: 'Initialize shared runtime services',
        steps: [
          BootstrapStep(
            name: 'Crashlytics',
            run: AppAnalytics.instance.ensureCrashlyticsInitialized,
          ),
          BootstrapStep(
            name: 'Event bus',
            run: () async {
              // TODO: await AppEventBusService.instance.init();
            },
          ),
          BootstrapStep(
            name: 'App links',
            run: () async {
              // TODO: await AppLinksService.instance.init(...)
              // TODO: AppLinksService.instance.registerKnownRoutes(...)
            },
          ),
          BootstrapStep(
            name: 'Remote config',
            run: () async {
              // TODO: AppRemoteConfig.instance.init(...)
            },
          ),
        ],
      ),

      // Phase 7b: Post-frame tasks
      BootstrapStep(
        name: 'Schedule post-frame tasks',
        run: () async {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future.wait([
              AppVersionService.instance.init(),
              AppBillingService.instance.init(),
              AppInAppReviewService.instance.init(),
            ]);
          });
        },
      ),
    ],
  );

  await pipeline.run();
}
""";
