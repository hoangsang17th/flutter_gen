import 'package:finvoras_gen/src/core/utils/map.dart';
import 'package:test/test.dart';

void main() {
  group('Map Utilities', () {
    test('mergeMap should merge two simple maps', () {
      final map1 = {'a': 1, 'b': 2};
      final map2 = {'b': 3, 'c': 4};
      final result = mergeMap([map1, map2]);
      expect(result, equals({'a': 1, 'b': 3, 'c': 4}));
    });

    test('mergeMap should merge nested maps recursively', () {
      final map1 = <String, dynamic>{
        'a': {'b': 1}
      };
      final map2 = <String, dynamic>{
        'a': {'c': 2}
      };
      final result = mergeMap([map1, map2], recursive: true);
      expect(
        result,
        equals({
          'a': {'b': 1, 'c': 2}
        }),
      );
    });

    test('mergeMap should overwrite nested maps if not recursive', () {
      final map1 = {
        'a': {'b': 1}
      };
      final map2 = {
        'a': {'c': 2}
      };
      final result = mergeMap([map1, map2], recursive: false);
      expect(
        result,
        equals({
          'a': {'c': 2}
        }),
      );
    });

    test('mergeMap should ignore null values if acceptNull is false', () {
      final map1 = {'a': 1};
      final map2 = {'a': null};
      final result = mergeMap([map1, map2], acceptNull: false);
      expect(result, equals({'a': 1}));
    });

    test('mergeMap should accept null values if acceptNull is true', () {
      final map1 = {'a': 1};
      final map2 = {'a': null};
      final result = mergeMap([map1, map2], acceptNull: true);
      expect(result, equals({'a': null}));
    });
  });
}
