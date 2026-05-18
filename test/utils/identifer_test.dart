import 'package:finvoras_gen/src/core/utils/identifer.dart';
import 'package:test/test.dart';

void main() {
  group('isValidIdentifier', () {
    test('should return true for valid identifiers', () {
      expect(isValidIdentifier('myVariable'), isTrue);
      expect(isValidIdentifier('_private'), isTrue);
      expect(isValidIdentifier('var123'), isTrue);
    });

    test('should return false for invalid identifiers', () {
      expect(isValidIdentifier('123var'), isFalse);
      expect(isValidIdentifier('my-var'), isFalse);
      expect(isValidIdentifier('my var'), isFalse);
      expect(isValidIdentifier(''), isFalse);
    });
  });

  group('isValidVariableIdentifier', () {
    test('should return true for valid variable names', () {
      expect(isValidVariableIdentifier('myVar'), isTrue);
    });

    test('should return false for reserved keywords', () {
      expect(isValidVariableIdentifier('class'), isFalse);
      expect(isValidVariableIdentifier('await'), isFalse);
      expect(isValidVariableIdentifier('void'), isFalse);
    });
  });

  group('convertToIdentifier', () {
    test('should replace invalid characters with underscores', () {
      expect(convertToIdentifier('hello-world'), equals('hello_world'));
      expect(convertToIdentifier('hello world!'), equals('hello_world_'));
    });

    test('should prefix with "a" if it starts with a digit', () {
      expect(convertToIdentifier('123hello'), equals('a123hello'));
    });

    test('should use custom prefix', () {
      expect(convertToIdentifier('123hello', prefix: 'v'), equals('v123hello'));
    });
  });
}
