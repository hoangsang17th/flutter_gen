import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:stageone/core/configs/di.config.dart';

final getIt = GetIt.instance;

@InjectableInit(initializerName: r'$initGetIt')
Future<void> configureDependencies() async => getIt.$initGetIt();
