import 'dart:math';

import 'package:emotic/core/constants.dart';
import 'package:emotic/core/semver.dart';
import 'package:sqflite/sqflite.dart';

bool _isBetween(double a, double n, double b) {
  return (a < n) && (n < b);
}

double getNumBetweenTwoNums({
  required double firstOrder,
  required double secondOrder,
}) {
  assert(
    firstOrder <= secondOrder,
    "Cannot find number between $firstOrder and $secondOrder",
  );
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

// TODO: change this to another table, not settings
Future<SemVer> getVersionInfoFromDb({required Database db}) async {
  await db.execute("""
CREATE TABLE IF NOT EXISTS $sqldbSettingsTableName
  (
    $sqldbSettingsKeyColName VARCHAR,
    $sqldbSettingsValueColName VARCHAR
  )
""");
  final settingsResult = await db.rawQuery("""
SELECT $sqldbSettingsValueColName
FROM $sqldbSettingsTableName
WHERE $sqldbSettingsKeyColName=$sqldbSettingsKeylastUsedVersion
  """);
  if (settingsResult.isNotEmpty) {
    return SemVer.fromString(
      settingsResult.first[sqldbSettingsValueColName] as String,
    );
  } else {
    return SemVer(major: 0, minor: 1, patch: 5); // Pre v0.1.6, the version info
    // wasn't saved, so assume its v0.1.5
  }
}
