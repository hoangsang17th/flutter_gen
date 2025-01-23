import 'package:flutter_gen_core/generators/integrations/integration.dart';

/// The main image integration, supporting all image asset types. See
/// [isSupport] for the exact supported mime types.
///
/// This integration is by enabled by default.
class ImageIntegration extends Integration {
  ImageIntegration(super.packageName);

  String get packageParameter => isPackage ? ' = package' : '';

  String get keyName =>
      isPackage ? "'packages/$packageName/\$_assetName'" : '_assetName';

  @override
  List<Import> get requiredImports => [];

  @override
  String get classOutput => _classDefinition;

  String get _classDefinition => '''class AssetGenImage {
  const AssetGenImage(this._assetName);

  final String _assetName;

${isPackage ? "\n  static const String package = '$packageName';" : ''}

  String get path => $keyName;
}
''';

  @override
  String get className => 'AssetGenImage';

  @override
  String classInstantiate(AssetType asset) {
    final buffer = StringBuffer(className);
    buffer.write('(');
    buffer.write('\'${asset.posixStylePath}\'');
    buffer.write(')');
    return buffer.toString();
  }

  @override
  bool isSupport(AssetType asset) {
    /// Flutter official supported image types. See
    /// https://api.flutter.dev/flutter/widgets/Image-class.html
    switch (asset.mime) {
      case 'image/jpeg':
      case 'image/png':
      case 'image/gif':
      case 'image/bmp':
      case 'image/vnd.wap.wbmp':
      case 'image/webp':
        return true;
      default:
        return false;
    }
  }

  @override
  bool get isConstConstructor => true;
}
