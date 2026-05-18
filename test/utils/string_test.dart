import 'package:finvoras_gen/src/core/utils/string.dart';
import 'package:test/test.dart';

void main() {
  group('StringExt', () {
    test('camelCase should convert snake_case to camelCase', () {
      expect('hello_world'.camelCase(), equals('helloWorld'));
      expect('foo_bar_baz'.camelCase(), equals('fooBarBaz'));
    });

    test('camelCase should convert PascalCase to camelCase', () {
      expect('HelloWorld'.camelCase(), equals('helloWorld'));
      expect('FooBarBaz'.camelCase(), equals('fooBarBaz'));
    });

    test('camelCase should handle spaces and hyphens', () {
      expect('hello world'.camelCase(), equals('helloWorld'));
      expect('hello-world'.camelCase(), equals('helloWorld'));
    });

    test('snakeCase should convert camelCase to snake_case', () {
      expect('helloWorld'.snakeCase(), equals('hello_world'));
      expect('fooBarBaz'.snakeCase(), equals('foo_bar_baz'));
    });

    test('snakeCase should convert PascalCase to snake_case', () {
      expect('HelloWorld'.snakeCase(), equals('hello_world'));
      expect('FooBarBaz'.snakeCase(), equals('foo_bar_baz'));
    });

    test('snakeCase should handle spaces and hyphens', () {
      expect('hello world'.snakeCase(), equals('hello_world'));
      expect('hello-world'.snakeCase(), equals('hello_world'));
    });
  });

  group('Top-level functions', () {
    test('camelCase function', () {
      expect(camelCase('hello_world'), equals('helloWorld'));
    });

    test('snakeCase function', () {
      expect(snakeCase('helloWorld'), equals('hello_world'));
    });
  });
}
