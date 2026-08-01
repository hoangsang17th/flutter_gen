const String diDartTemplate = r"""
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:{{app_name}}/core/configs/di.config.dart';

final getIt = GetIt.instance;

@InjectableInit(initializerName: r'$initGetIt')
Future<void> configureDependencies() async => getIt.$initGetIt();
""";
