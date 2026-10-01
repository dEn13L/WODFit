import 'package:flutter_test/flutter_test.dart';
import 'package:wod_fit/presentation/screens/workout/result_input/result_input_parsers.dart';

void main() {
  group('parseWorkoutTime', () {
    test('normalizes 01:05 and converts it to milliseconds', () {
      final result = parseWorkoutTime('01', '05');

      expect(result?.formatted, '01:05');
      expect(result?.milliseconds, 65000);
    });

    test('rejects seconds outside 00-59 and negative values', () {
      expect(parseWorkoutTime('1', '60'), isNull);
      expect(parseWorkoutTime('-1', '05'), isNull);
    });
  });

  group('parseNonNegativeDecimal', () {
    test('accepts comma and point decimal separators', () {
      expect(parseNonNegativeDecimal('12,5'), 12.5);
      expect(parseNonNegativeDecimal('12.5'), 12.5);
    });

    test('rejects negative and malformed values', () {
      expect(parseNonNegativeDecimal('-1'), isNull);
      expect(parseNonNegativeDecimal('1,2,3'), isNull);
    });
  });

  test('parseNonNegativeInt rejects negative values', () {
    expect(parseNonNegativeInt('0'), 0);
    expect(parseNonNegativeInt('-1'), isNull);
  });
}
