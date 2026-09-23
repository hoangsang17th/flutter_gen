import 'package:flutter/material.dart';

import 'package:app_core/app_core.dart';
import 'package:app_orchestrator/app_orchestrator.dart';
import 'package:app_shell_utils/app_shell_utils.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    AppActions.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return AppOrchestrator(
      builder: (context, orchestrator) {
        final controller = orchestrator.controller;

        return GetMaterialApp(
          // TODO: Use AppLocalesKeys.app_name.l when localization is ready
          title: 'stageone',
          theme: AppThemed.themeData,
          themeMode: controller.themeMode,
          debugShowCheckedModeBanner: false,
          builder: EasyLoading.init(),
          // TODO: Configure your bindings, pages, and routes here
          // initialBinding: AppControllerBinding(),
          // getPages: AppPages.pages,
          // initialRoute: AppRoutes.dashboard,
          home: const Scaffold(
            body: Center(
              child: Text('stageone'),
            ),
          ),
          navigatorKey: orchestrator.navigatorKey,
          navigatorObservers: [
            if (Firebase.apps.isNotEmpty)
              AppFirebaseAnalyticsService.instance.observer,
            // TODO: Add app route observer
            // appRouteObserver,
          ],
          scaffoldMessengerKey: orchestrator.scaffoldMessengerKey,
          locale: controller.locale ?? controller.fallbackLocale,
          fallbackLocale: controller.fallbackLocale,
          supportedLocales: controller.supportedLocales,
          localizationsDelegates: const [
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
