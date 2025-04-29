import 'dart:math';

import 'package:emotic/core/helper_functions.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('Double values operation for list ordering', () {
    test('Getting number between 0 and 1', () async {
      final value = getNumBetweenTwoNums(firstOrder: 0, secondOrder: 1);
      expect(
        0 < value && value < 1,
        isTrue,
      );
    });

    test('Getting number between -8 and -7', () async {
      final value = getNumBetweenTwoNums(firstOrder: -8, secondOrder: -7);
      expect(
        -8 < value && value < -7,
        isTrue,
      );
    });

    test('Both numbers should\'nt be equal, will throw assertion error',
        () async {
      expect(
        () => getNumBetweenTwoNums(firstOrder: 0, secondOrder: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Number between random doubles', () async {
      var a = Random().nextDouble();
      var b = Random().nextDouble();
      if (b < a) {
        (a, b) = (b, a);
      }
      final value = getNumBetweenTwoNums(firstOrder: a, secondOrder: b);
      expect(
        a < value && value < b,
        isTrue,
      );
    });
  });
}
