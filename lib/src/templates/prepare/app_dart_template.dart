const String appDartTemplate = r"""
import 'package:{{app_name}}/generated/locales.gen.dart';
import 'package:flutter/material.dart';

{{#is_monorepo}}
import 'package:app_core/app_core.dart';
import 'package:app_orchestrator/app_orchestrator.dart';
import 'package:app_shell_utils/app_shell_utils.dart';
{{/is_monorepo}}

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
    {{#is_monorepo}}
    AppActions.instance.init();
    {{/is_monorepo}}
  }

  @override
  Widget build(BuildContext context) {
    {{#is_monorepo}}
    return AppOrchestrator(
      builder: (context, orchestrator) {
        final controller = orchestrator.controller;

        return GetMaterialApp(
          // TODO: Use AppLocalesKeys.app_name.l when localization is ready
          title: '{{app_name}}',
          theme: AppThemed.themeData,
          themeMode: controller.themeMode,
          debugShowCheckedModeBanner: false,
          builder: EasyLoading.init(),
          // TODO: Configure your bindings, pages, and routes here
          // initialBinding: AppControllerBinding(),
          // getPages: AppPages.pages,
          // initialRoute: AppRoutes.dashboard,
          navigatorKey: orchestrator.navigatorKey,
          navigatorObservers: [
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
    {{/is_monorepo}}
    {{^is_monorepo}}
    return GetMaterialApp(
      title: '{{app_name}}',
      debugShowCheckedModeBanner: false,
      builder: EasyLoading.init(),
      // TODO: Configure your bindings, pages, and routes here
      // initialBinding: AppControllerBinding(),
      // getPages: AppPages.pages,
      // initialRoute: AppRoutes.dashboard,
      localizationsDelegates: const [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
    {{/is_monorepo}}
  }
}
""";
