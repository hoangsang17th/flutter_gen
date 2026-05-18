import 'package:finvoras_gen/src/core/utils/color.dart';
import 'package:test/test.dart';

void main() {
  group('Color Utilities', () {
    test('hexFromColor should convert 0xBB1122 to #BB1122', () {
      expect(hexFromColor('0xBB1122'), equals('#BB1122'));
      expect(hexFromColor('0x112233'), equals('#112233'));
    });

    test('colorFromHex should convert #BB1122 to 0xFFBB1122', () {
      expect(colorFromHex('#BB1122'), equals('0xFFBB1122'));
      expect(colorFromHex('BB1122'), equals('0xFFBB1122'));
    });

    test('colorFromHex should handle 8-digit hex', () {
      expect(colorFromHex('#AABB1122'), equals('0xAABB1122'));
    });

    test('swatchFromPrimaryHex should generate a valid swatch', () {
      final swatch = swatchFromPrimaryHex('BB1122');
      expect(swatch.length, equals(10));
      expect(swatch.containsKey(50), isTrue);
      expect(swatch.containsKey(500), isTrue);
      expect(swatch[500], equals('0xFFBB1122'));
    });

    test('accentSwatchFromPrimaryHex should generate a valid accent swatch',
        () {
      final swatch = accentSwatchFromPrimaryHex('BB1122');
      expect(swatch.length, equals(4));
      expect(swatch.containsKey(100), isTrue);
      expect(swatch.containsKey(700), isTrue);
    });
  });
}
