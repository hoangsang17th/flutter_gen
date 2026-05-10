class PrepareTemplates {
  static const String localeJson = '''{
  "app_name": "{{appName}}"
}
''';

  static const String injectionDart = '''import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async => getIt.init();
''';

  static const String prepareDart = '''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
// TODO: Import your services and DI here
// import '../../src/di/injection.dart';

Future<void> prepareApp(WidgetsBinding binding) async {
  // 1. Error widget builder
  ErrorWidget.builder = (_) => const SizedBox.shrink();

  // 2. Preserve splash screen
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // 3. System UI Mode
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
  );

  // 4. Dependency Injection
  // await configureDependencies();
  // registerAppOrchestratorDependencies();

  // 5. Core Services Initialization
  // await AppPathService.instance.init();
  // await AppKeyStorage.instance.init();
  // await AppActions.instance.init();

  // 6. Preferred Orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 7. Remove splash screen
  FlutterNativeSplash.remove();
}
''';

  static const String mainDart = '''import 'package:flutter/material.dart';
{{imports}}
import 'core/config/prepare.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  await prepareApp(binding);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppOrchestrator(
{{materialApp}}
    );
  }
}

{{router}}

class AppOrchestrator extends StatelessWidget {
  final Widget child;
  const AppOrchestrator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // AppOrchestrator wraps the main app to provide global providers or configurations
    return child;
  }
}
''';

  static const String blocMaterialApp = '''      child: MaterialApp.router(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),''';

  static const String getxMaterialApp = '''      child: GetMaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(child: Text('App Prepared with GetX!')),
        ),
      ),''';

  static const String blocRouter = '''final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('App Prepared with Bloc & GoRouter!')),
      ),
    ),
  ],
);''';
}
