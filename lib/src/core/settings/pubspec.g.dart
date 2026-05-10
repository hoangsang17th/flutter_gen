// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pubspec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pubspec _$PubspecFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['name', 'finvoras_gen', 'flutter']);
  return Pubspec(
    packageName: json['name'] as String,
    flutterGen: FlutterGen.fromJson(json['finvoras_gen'] as Map),
    flutter: Flutter.fromJson(json['flutter'] as Map),
  );
}

Map<String, dynamic> _$PubspecToJson(Pubspec instance) => <String, dynamic>{
      'name': instance.packageName,
      'finvoras_gen': instance.flutterGen,
      'flutter': instance.flutter,
    };

Flutter _$FlutterFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['assets', 'fonts']);
  return Flutter(
    assets: (json['assets'] as List<dynamic>).map((e) => e as Object).toList(),
    fonts: (json['fonts'] as List<dynamic>)
        .map((e) => FlutterFonts.fromJson(e as Map))
        .toList(),
  );
}

Map<String, dynamic> _$FlutterToJson(Flutter instance) => <String, dynamic>{
      'assets': instance.assets,
      'fonts': instance.fonts,
    };

FlutterFonts _$FlutterFontsFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['family']);
  return FlutterFonts(family: json['family'] as String);
}

Map<String, dynamic> _$FlutterFontsToJson(FlutterFonts instance) =>
    <String, dynamic>{'family': instance.family};

FlutterGen _$FlutterGenFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'output',
      'line_length',
      'parse_metadata',
      'assets',
      'fonts',
      'integrations',
      'colors',
    ],
  );
  return FlutterGen(
    appId: json['app_id'] as String?,
    output: json['output'] as String,
    lineLength: (json['line_length'] as num).toInt(),
    parseMetadata: json['parse_metadata'] as bool,
    assets: FlutterGenAssets.fromJson(json['assets'] as Map),
    fonts: FlutterGenFonts.fromJson(json['fonts'] as Map),
    integrations: FlutterGenIntegrations.fromJson(json['integrations'] as Map),
    colors: FlutterGenColors.fromJson(json['colors'] as Map),
    locales: FlutterGenLocales.fromJson(json['locales'] as Map),
  );
}

Map<String, dynamic> _$FlutterGenToJson(FlutterGen instance) =>
    <String, dynamic>{
      'app_id': instance.appId,
      'output': instance.output,
      'line_length': instance.lineLength,
      'parse_metadata': instance.parseMetadata,
      'assets': instance.assets,
      'fonts': instance.fonts,
      'integrations': instance.integrations,
      'colors': instance.colors,
      'locales': instance.locales,
    };

FlutterGenColors _$FlutterGenColorsFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['enabled', 'inputs', 'outputs']);
  return FlutterGenColors(
    enabled: json['enabled'] as bool,
    inputs: (json['inputs'] as List<dynamic>).map((e) => e as String).toList(),
    outputs: FlutterGenElementOutputs.fromJson(json['outputs'] as Map),
  );
}

Map<String, dynamic> _$FlutterGenColorsToJson(FlutterGenColors instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'inputs': instance.inputs,
      'outputs': instance.outputs,
    };

FlutterGenAssets _$FlutterGenAssetsFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['enabled', 'outputs', 'exclude']);
  return FlutterGenAssets(
    enabled: json['enabled'] as bool,
    packageParameterEnabled: json['package_parameter_enabled'] as bool?,
    style: json['style'] as String?,
    outputs: FlutterGenElementAssetsOutputs.fromJson(json['outputs'] as Map),
    exclude:
        (json['exclude'] as List<dynamic>).map((e) => e as String).toList(),
  );
}

Map<String, dynamic> _$FlutterGenAssetsToJson(FlutterGenAssets instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'package_parameter_enabled': instance.packageParameterEnabled,
      'style': instance.style,
      'outputs': instance.outputs,
      'exclude': instance.exclude,
    };

FlutterGenFonts _$FlutterGenFontsFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['enabled', 'outputs']);
  return FlutterGenFonts(
    enabled: json['enabled'] as bool,
    outputs: FlutterGenElementFontsOutputs.fromJson(json['outputs'] as Map),
  );
}

Map<String, dynamic> _$FlutterGenFontsToJson(FlutterGenFonts instance) =>
    <String, dynamic>{'enabled': instance.enabled, 'outputs': instance.outputs};

FlutterGenIntegrations _$FlutterGenIntegrationsFromJson(Map json) {
  $checkKeys(
    json,
    requiredKeys: const ['image', 'flutter_svg', 'rive', 'lottie'],
  );
  return FlutterGenIntegrations(
    image: json['image'] as bool,
    flutterSvg: json['flutter_svg'] as bool,
    rive: json['rive'] as bool,
    lottie: json['lottie'] as bool,
  );
}

Map<String, dynamic> _$FlutterGenIntegrationsToJson(
  FlutterGenIntegrations instance,
) =>
    <String, dynamic>{
      'image': instance.image,
      'flutter_svg': instance.flutterSvg,
      'rive': instance.rive,
      'lottie': instance.lottie,
    };

FlutterGenElementOutputs _$FlutterGenElementOutputsFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['class_name']);
  return FlutterGenElementOutputs(className: json['class_name'] as String);
}

Map<String, dynamic> _$FlutterGenElementOutputsToJson(
  FlutterGenElementOutputs instance,
) =>
    <String, dynamic>{'class_name': instance.className};

FlutterGenElementAssetsOutputs _$FlutterGenElementAssetsOutputsFromJson(
  Map json,
) {
  $checkKeys(json, requiredKeys: const ['class_name', 'style']);
  return FlutterGenElementAssetsOutputs(
    className: json['class_name'] as String,
    packageParameterEnabled:
        json['package_parameter_enabled'] as bool? ?? false,
    directoryPathEnabled: json['directory_path_enabled'] as bool? ?? false,
    style: FlutterGenElementAssetsOutputsStyle.fromJson(
      json['style'] as String,
    ),
  );
}

Map<String, dynamic> _$FlutterGenElementAssetsOutputsToJson(
  FlutterGenElementAssetsOutputs instance,
) =>
    <String, dynamic>{
      'class_name': instance.className,
      'package_parameter_enabled': instance.packageParameterEnabled,
      'directory_path_enabled': instance.directoryPathEnabled,
      'style': instance.style,
    };

FlutterGenElementFontsOutputs _$FlutterGenElementFontsOutputsFromJson(
  Map json,
) {
  $checkKeys(json, requiredKeys: const ['class_name']);
  return FlutterGenElementFontsOutputs(
    className: json['class_name'] as String,
    packageParameterEnabled:
        json['package_parameter_enabled'] as bool? ?? false,
  );
}

Map<String, dynamic> _$FlutterGenElementFontsOutputsToJson(
  FlutterGenElementFontsOutputs instance,
) =>
    <String, dynamic>{
      'class_name': instance.className,
      'package_parameter_enabled': instance.packageParameterEnabled,
    };

FlutterGenLocales _$FlutterGenLocalesFromJson(Map json) {
  $checkKeys(json, requiredKeys: const ['enabled', 'folder', 'outputs']);
  return FlutterGenLocales(
    enabled: json['enabled'] as bool,
    folder: json['folder'] as String,
    outputs: FlutterGenElementLocalesOutputs.fromJson(json['outputs'] as Map),
  );
}

Map<String, dynamic> _$FlutterGenLocalesToJson(FlutterGenLocales instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'folder': instance.folder,
      'outputs': instance.outputs,
    };

FlutterGenElementLocalesOutputs _$FlutterGenElementLocalesOutputsFromJson(
  Map json,
) {
  $checkKeys(json, requiredKeys: const ['translation_name', 'keys_name']);
  return FlutterGenElementLocalesOutputs(
    translationName: json['translation_name'] as String,
    keysName: json['keys_name'] as String,
  );
}

Map<String, dynamic> _$FlutterGenElementLocalesOutputsToJson(
  FlutterGenElementLocalesOutputs instance,
) =>
    <String, dynamic>{
      'translation_name': instance.translationName,
      'keys_name': instance.keysName,
    };
