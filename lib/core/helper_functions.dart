import 'dart:math';

bool _isBetween(double a, double n, double b) {
  return (a < n) && (n < b);
}

/// Assuming that firstOrder is less than secondOrder, get another
/// double which is in between those two.
double getNumBetweenTwoNums({
  required double firstOrder,
  required double secondOrder,
}) {
  if (firstOrder >= secondOrder) {
    throw AssertionError(
        "Cannot find number between $firstOrder and $secondOrder");
  }
  final longestPrecision = max(
    firstOrder.toString().length,
    secondOrder.toString().length,
  );

  double sumAvg = (firstOrder + secondOrder) / 2;
  double numBetween = sumAvg.floorToDouble();

  for (int i = 1; i <= longestPrecision; i++) {
    if (_isBetween(firstOrder, numBetween, secondOrder)) {
      break;
    } else {
      numBetween = double.parse(
        sumAvg.toString().substring(
              0,
              (sumAvg.isNegative)
                  ? i + 1
                  : i, // If its negative, offset for the negative sign
            ),
      );
    }
  }
  if (!_isBetween(firstOrder, numBetween, secondOrder)) {
    numBetween = sumAvg;
  }
  return numBetween;
}
