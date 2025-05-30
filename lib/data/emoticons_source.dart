import 'dart:io' as io;
import 'package:async/async.dart';
import 'package:emotic/core/helper_functions.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/semver.dart';
import 'package:path/path.dart' as p;
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/emoticon.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

enum ImportStrategy { merge, overwrite }

abstract class EmoticonsSource {
  Future<List<Emoticon>> getEmoticons();
  Future<List<String>> getTags();
}

abstract class EmoticonsStore extends EmoticonsSource {
  Future<void> saveEmoticon({
    required NewOrModifyEmoticon newOrModifyEmoticon,
  }); // In case of update
  Future<void> deleteEmoticon({
    required Emoticon emoticon,
  });
  Future<void> saveTag({
    required String tag,
  });
  Future<void> deleteTag({
    required String tag,
  });
  Future<void> clearAllData();
  Future<void> modifyEmoticonOrder({
    required Emoticon emoticon,
    required int newOrder,
  });
  Future<void> modifyTagOrder({
    required String tag,
    required int newOrder,
  });
}

Future<List<Emoticon>> _getEmoticonsFromDb({required Database db}) async {
  List<Emoticon> emoticons = [];
  final emoticonSet = await db.rawQuery("""
SELECT 
  em.$sqldbEmoticonsId,
  em.$sqldbEmoticonsText 
FROM 
  $sqldbEmoticonsTableName em
LEFT JOIN
  $sqldbEmoticonsOrderingTableName ord
ON
  em.$sqldbEmoticonsId=ord.$sqldbEmoticonsOrderingEmoticonId
ORDER BY
  ord.$sqldbEmoticonsOrderingUserOrder ASC NULLS LAST,
  em.$sqldbEmoticonsId ASC
""");
  for (final row in emoticonSet) {
    final emoticonId = int.parse(row[sqldbEmoticonsId].toString());
    final tagSet = await db.rawQuery(
      """
  SELECT tags.$sqldbTagName 
    FROM $sqldbTagsTableName AS tags,
         $sqldbEmoticonsToTagsJoinTableName AS tagjoin
    WHERE tagjoin.$sqldbEmoticonsId==?
      AND tagjoin.$sqldbTagId==tags.$sqldbTagId
""",
      [
        emoticonId,
      ],
    );
    final emoticon = Emoticon(
      id: emoticonId,
      text: row[sqldbEmoticonsText].toString(),
      emoticonTags: tagSet.map(
        (Map<String, Object?> row) {
          return row[sqldbTagName].toString();
        },
      ).toList(),
    );
    emoticons.add(emoticon);
  }
  return emoticons;
}

Future<List<String>> _getTagsFromDb({required Database db}) async {
  final tagResultSet = await db.rawQuery("""
SELECT 
  tg.$sqldbTagName 
FROM 
  $sqldbTagsTableName tg
LEFT JOIN
  $sqldbTagsOrderingTableName ord
ON 
  tg.$sqldbTagId=ord.$sqldbTagsOrderingTagId
ORDER BY
  ord.$sqldbTagsOrderingUserOrder ASC NULLS LAST,
  tg.$sqldbTagId ASC
      """);
  List<String> tags = tagResultSet
      .map(
        (element) => element[sqldbTagName].toString(),
      )
      .toList();
  return tags;
}

class EmoticonsSourceAssetDB implements EmoticonsSource {
  final AssetBundle assetBundle;
  final EmoticAppDataDirectory emoticAppDataDirectory;
  EmoticonsSourceAssetDB({
    required this.assetBundle,
    required this.emoticAppDataDirectory,
  });
  Database? sourceDb;
  io.File? dbFile;

  Future<void> _copyDbFromAsset() async {
    if (sourceDb == null) {
      final sourceDbFile = await assetBundle.load(emoticonsSourceDbAsset);
      final appDataPath = await emoticAppDataDirectory.getAppDataDir();
      dbFile = io.File(p.join(appDataPath, emoticonsSourceDbName));
      await dbFile!
          .writeAsBytes(sourceDbFile.buffer.asUint8List(), flush: true);
      sourceDb = await openDatabase(dbFile!.path);
    }
  }

  Future<void> dispose() async {
    await sourceDb?.close();
    await dbFile?.delete();
  }

  @override
  Future<List<Emoticon>> getEmoticons() async {
    await _copyDbFromAsset();
    return _getEmoticonsFromDb(db: sourceDb!);
  }

  @override
  Future<List<String>> getTags() async {
    await _copyDbFromAsset();
    return _getTagsFromDb(db: sourceDb!);
  }
}

class EmoticonsSqliteSource implements EmoticonsStore {
  final Database db;
  final EmoticAppDataDirectory emoticAppDataDirectory;
  EmoticonsSqliteSource({
    required this.db,
    required this.emoticAppDataDirectory,
  }) {
    _ensureTables();
  }

  Future<void> _ensureTables() async {
    await db.execute(SQLStatements.createEmoticonTableStmt);
    await db.execute(SQLStatements.createTagsTableStmt);
    await db.execute(SQLStatements.createEmoticonTagMappingTableStmt);
    await db.execute(SQLStatements.createEmoticonsOrderingTableStmt);
    await _prefillEmoticonsOrdering();
    await db.execute(SQLStatements.createTagsOrderingTableStmt);
    await _prefillTagsOrdering();
  }

  Future<void> _prefillEmoticonsOrdering() async {
    final orderCount = "order_count";
    final existing = await db.rawQuery("""
SELECT 
  COUNT(*) AS $orderCount 
FROM
  $sqldbEmoticonsOrderingTableName
    """);
    if (existing.single[orderCount] == 0) {
      getLogger().config("Prefilling emoticons ordering");
      await db.rawInsert("""
INSERT INTO
  $sqldbEmoticonsOrderingTableName
  ($sqldbEmoticonsOrderingEmoticonId, $sqldbEmoticonsOrderingUserOrder)
SELECT 
  $sqldbEmoticonsId $sqldbEmoticonsOrderingEmoticonId, 
  CAST($sqldbEmoticonsId AS REAL) $sqldbEmoticonsOrderingUserOrder
FROM
  $sqldbEmoticonsTableName
      """);
    }
  }

  Future<void> _prefillTagsOrdering() async {
    final orderCount = "order_count";
    final existing = await db.rawQuery("""
SELECT 
  COUNT(*) AS $orderCount 
FROM
  $sqldbTagsOrderingTableName
    """);
    if (existing.single[orderCount] == 0) {
      getLogger().config("Prefilling tags ordering");
      await db.rawInsert("""
INSERT INTO
  $sqldbTagsOrderingTableName
  ($sqldbTagsOrderingTagId, $sqldbTagsOrderingUserOrder)
SELECT 
  $sqldbTagId $sqldbTagsOrderingTagId,
  CAST($sqldbTagId AS REAL) $sqldbTagsOrderingUserOrder
FROM
  $sqldbTagsTableName
      """);
    }
  }

  @override
  Future<List<String>> getTags() async {
    await _ensureTables();
    return _getTagsFromDb(db: db);
  }

  @override
  Future<List<Emoticon>> getEmoticons() async {
    await _ensureTables();
    return _getEmoticonsFromDb(db: db);
  }

  @override
  Future<void> saveEmoticon({
    required NewOrModifyEmoticon newOrModifyEmoticon,
  }) async {
    getLogger().config("Saving $newOrModifyEmoticon");
    int emoticonId;
    if (newOrModifyEmoticon.oldEmoticon == null) {
      final emoticonResultSet = await db.rawQuery(
        SQLStatements.emoticonExistsCheckStmt,
        [newOrModifyEmoticon.text],
      );
      if (emoticonResultSet.isEmpty) {
        // Only inserting if its not there
        emoticonId = await db.rawInsert(
          SQLStatements.emoticonInsertStmt,
          [newOrModifyEmoticon.text],
        );
        await _appendToEmoticonsOrder(emoticonId: emoticonId);
      } else {
        emoticonId = emoticonResultSet.first[sqldbEmoticonsId] as int;
      }
    } else {
      final emoticonResultSet = await db.rawQuery(
        SQLStatements.emoticonExistsCheckStmt,
        [newOrModifyEmoticon.oldEmoticon!.text],
      );
      if (emoticonResultSet.length != 1) {
        getLogger().warning(
          "Got ${emoticonResultSet.length} length result when checking"
          " emoticonExistsCheckStmt in saveEmoticon",
        );
      }
      emoticonId = emoticonResultSet.first[sqldbEmoticonsId] as int;
      await db.execute(SQLStatements.emoticonUpdateStmt,
          [newOrModifyEmoticon.text, emoticonId]);

      // Only do this if we're updating an old emoticon, not when a new
      // (albeit duplicate) one is added, as in the case of app update, when its
      // loaded from assets db
      await db.execute(SQLStatements.removeEmoticonFromJoinStmt, [emoticonId]);
    }

    // Its easier this way
    for (final tag in newOrModifyEmoticon.emoticonTags) {
      await saveTag(tag: tag);
      final tagId = await _getTagId(tag: tag);
      if (tagId != null) {
        await db.execute(SQLStatements.emoticonTagMapStmt, [emoticonId, tagId]);
      } else {
        throw Error.safeToString(
          "Couldnt get tagId of $tag, unable to save emoticon-tag linking",
        );
      }
    }
  }

  @override
  Future<void> deleteEmoticon({required Emoticon emoticon}) async {
    final emoticonResultSet = await db.rawQuery(
      SQLStatements.emoticonExistsCheckStmt,
      [emoticon.text],
    );
    if (emoticonResultSet.isNotEmpty) {
      if (emoticonResultSet.length != 1) {
        getLogger().warning(
          "Got ${emoticonResultSet.length} length result when checking"
          " emoticonExistsCheckStmt in deleteEmoticon",
        );
      }
      final emoticonIdToRemove =
          int.parse(emoticonResultSet.first[sqldbEmoticonsId].toString());
      await db.execute(
        SQLStatements.emoticonRemoveStmt,
        [emoticonIdToRemove],
      );
      await db.execute(
        SQLStatements.removeEmoticonFromJoinStmt,
        [emoticonIdToRemove],
      );
      await db.rawDelete(
        """
DELETE FROM 
  $sqldbEmoticonsOrderingTableName
WHERE
  $sqldbEmoticonsOrderingEmoticonId=?
      """,
        [emoticonIdToRemove],
      );
    }
  }

  @override
  Future<void> saveTag({required String tag}) async {
    final tagId = await _getTagId(tag: tag);
    if (tagId == null) {
      final tagId = await db.rawInsert(
        SQLStatements.tagInsertStmt,
        [tag],
      );
      await _appendToTagsOrder(tagId: tagId);
    }
  }

  @override
  Future<void> deleteTag({required String tag}) async {
    final tagId = await _getTagId(tag: tag);
    if (tagId != null) {
      await db.execute(
        SQLStatements.tagDeleteStmt,
        [tagId],
      );
      await db.execute(
        SQLStatements.removeTagFromJoinStmt,
        [tagId],
      );
      await db.rawDelete(
        """
DELETE FROM 
  $sqldbTagsOrderingTableName
WHERE
  $sqldbTagsOrderingTagId=?
      """,
        [tagId],
      );
    }
  }

  @override
  Future<void> clearAllData() async {
    await db.rawDelete("DELETE FROM $sqldbEmoticonsTableName");
    await db.rawDelete("DELETE FROM $sqldbEmoticonsToTagsJoinTableName");
    await db.rawDelete("DELETE FROM $sqldbTagsTableName");
    await db.rawDelete("DELETE FROM $sqldbEmoticonsOrderingTableName");
    await db.rawDelete("DELETE FROM $sqldbTagsOrderingTableName");
  }

  Future<void> _appendToEmoticonsOrder({
    required int emoticonId,
  }) async {
    final currentHighestOrder = (await getCurrentMinAndMaxOrder(
      db: db,
      tableName: sqldbEmoticonsOrderingTableName,
      orderColumnName: sqldbEmoticonsOrderingUserOrder,
    ))
        ?.$2;
    await db.rawInsert(
      """
INSERT INTO
  $sqldbEmoticonsOrderingTableName
  ($sqldbEmoticonsOrderingEmoticonId, $sqldbEmoticonsOrderingUserOrder)
VALUES
  (?, ?)
    """,
      [
        emoticonId,
        (currentHighestOrder ?? 0.0) + 1,
      ],
    );
  }

  Future<void> _appendToTagsOrder({
    required int tagId,
  }) async {
    final currentHighestOrder = (await getCurrentMinAndMaxOrder(
      db: db,
      tableName: sqldbTagsOrderingTableName,
      orderColumnName: sqldbTagsOrderingUserOrder,
    ))
        ?.$2;
    await db.rawInsert(
      """
INSERT INTO
  $sqldbTagsOrderingTableName
  ($sqldbTagsOrderingTagId, $sqldbTagsOrderingUserOrder)
VALUES
  (?, ?)
    """,
      [
        tagId,
        (currentHighestOrder ?? 0.0) + 1,
      ],
    );
  }

  @override
  Future<void> modifyEmoticonOrder({
    required Emoticon emoticon,
    required int newOrder,
  }) async {
    getLogger().config("Changing order of $emoticon to $newOrder index");
    await db.rawDelete(
      """
DELETE FROM
  $sqldbEmoticonsOrderingTableName
WHERE
  $sqldbEmoticonsOrderingEmoticonId=?
      """,
      [emoticon.id],
    );

    final nMinus1AndNthValue = await getNMinus1thAndNthOrderValue(
      db: db,
      tableName: sqldbEmoticonsOrderingTableName,
      orderColumnName: sqldbEmoticonsOrderingUserOrder,
      n: newOrder,
    );
    getLogger().config("N-1th and Nth order values $nMinus1AndNthValue");
    final (firstOrder, secondOrder) = getFirstAndSecondOrder(
      nMinus1thAndNthValue: nMinus1AndNthValue,
    );
    getLogger().config("firstOrder: $firstOrder and secondOrder: $secondOrder");
    final newOrderValue = getNumBetweenTwoNums(
      firstOrder: firstOrder,
      secondOrder: secondOrder,
    );

    getLogger().config("New order value between is $newOrderValue");
    // Insert the emoticon with its order
    await db.rawInsert(
      """
INSERT INTO
  $sqldbEmoticonsOrderingTableName
VALUES
  (?, ?)
    """,
      [
        emoticon.id,
        newOrderValue,
      ],
    );
  }

  Future<int?> _getTagId({required String tag}) async {
    final tagResult = await db.rawQuery(
      SQLStatements.tagExistsCheckStmt,
      [tag],
    );
    if (tagResult.length != 1) {
      if (tagResult.length > 1) {
        getLogger().warning(
          "Got ${tagResult.length} length result when getting tagId",
        );
      }
      return tagResult.firstOrNull?[sqldbTagId] as int?;
    } else {
      return tagResult.first[sqldbTagId] as int;
    }
  }

  @override
  Future<void> modifyTagOrder({
    required String tag,
    required int newOrder,
  }) async {
    // Checking if the tag has an order position already
    final tagId = await _getTagId(tag: tag);
    if (tagId == null) {
      throw ArgumentError.value(
        tag,
        "Invalid tag",
        "Tag does not exist in the database",
      );
    }
    getLogger().config("Changing order of $tag to $newOrder index");
    await db.rawDelete(
      """
DELETE FROM
  $sqldbTagsOrderingTableName
WHERE
  $sqldbTagsOrderingTagId=?
      """,
      [tagId],
    );

    final nMinus1AndNthValue = await getNMinus1thAndNthOrderValue(
      db: db,
      tableName: sqldbTagsOrderingTableName,
      orderColumnName: sqldbTagsOrderingUserOrder,
      n: newOrder,
    );
    getLogger().config("N-1th and Nth order values $nMinus1AndNthValue");
    final (firstOrder, secondOrder) = getFirstAndSecondOrder(
      nMinus1thAndNthValue: nMinus1AndNthValue,
    );
    getLogger().config("firstOrder: $firstOrder and secondOrder: $secondOrder");

    final newOrderValue = getNumBetweenTwoNums(
      firstOrder: firstOrder,
      secondOrder: secondOrder,
    );
    getLogger().config("New order value between is $newOrderValue");
    // Insert the emoticon with its order
    await db.rawInsert(
      """
INSERT INTO
  $sqldbTagsOrderingTableName
VALUES
  (?, ?)
    """,
      [
        tagId,
        newOrderValue,
      ],
    );
  }

  Future<Result<void>> importFromDb({
    required ImportStrategy importStrategy,
  }) async {
    try {
      final inputFile = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: "Import data",
      );
      if (inputFile?.paths.single == null) {
        return Result.error(ArgumentError.notNull("Path not selected"));
      }
      String dbPath = inputFile!.paths.single!;
      Database sourceDb = await openDatabase(dbPath);
      final dbVersion = await getMetadataVersion(db: sourceDb);
      if (dbVersion < SemVer.fromString("0.1.6")) {
        await sourceDb.execute(SQLStatements.createEmoticonsOrderingTableStmt);
        await sourceDb.execute(SQLStatements.createTagsOrderingTableStmt);
      }
      final emoticons = await _getEmoticonsFromDb(db: sourceDb);
      final tags = await _getTagsFromDb(db: sourceDb);
      switch (importStrategy) {
        case ImportStrategy.overwrite:
          await clearAllData();
          continue merge;
        merge:
        case ImportStrategy.merge:
          for (final tag in tags) {
            await saveTag(tag: tag);
          }
          for (final emoticon in emoticons) {
            await saveEmoticon(
              newOrModifyEmoticon: NewOrModifyEmoticon.copyFromEmoticon(
                emoticon,
              ),
            );
          }
      }

      await sourceDb.close();
      return Result.value(null);
    } on Exception catch (error, stacktrace) {
      return Result.error(error, stacktrace);
    }
  }

  Future<Result<void>> exportToDb() async {
    try {
      final today = DateTime.now();
      String? outputFile;
      final fileName =
          "Emotic_${today.year}_${today.month}_${today.day}_${today.hour}_${today.minute}.sqlite";
      final cacheDir = await emoticAppDataDirectory.getAppCacheDir();

      final outputDbPath = p.join(cacheDir, fileName);
      await db.execute("VACUUM");
      await io.File(db.path).copy(outputDbPath);
      final outputDb = await openDatabase(outputDbPath);
      // await outputDb.execute("""DROP TABLE $sqldbSettingsTableName""");
      await outputDb.close();
      final dbFile = io.File(outputDbPath);
      outputFile = await FilePicker.platform.saveFile(
        dialogTitle: "Save data",
        bytes: await dbFile.readAsBytes(),
        fileName: fileName,
      );
      // In desktop, saveFile doesn't actually save the file bytes, it only
      // returns a file path, where we have to actually write it
      if (!(io.Platform.isAndroid || io.Platform.isIOS) && outputFile != null) {
        await dbFile.copy(outputFile);
      }

      if (outputFile != null) {
        return Result.value(null);
      } else {
        return Result.error(UnimplementedError("Unable to save"));
      }
    } on Exception catch (error, stacktrace) {
      return Result.error(error, stacktrace);
    }
  }
}

typedef PreparedStatement = String;

class SQLStatements {
  static const PreparedStatement createEmoticonTableStmt = """
CREATE TABLE IF NOT EXISTS $sqldbEmoticonsTableName 
(
  $sqldbEmoticonsId INTEGER PRIMARY KEY,
  $sqldbEmoticonsText VARCHAR
)
""";

  static const PreparedStatement createTagsTableStmt = """
CREATE TABLE IF NOT EXISTS $sqldbTagsTableName
(
  $sqldbTagId INTEGER PRIMARY KEY,
  $sqldbTagName VARCHAR
)
""";

  static const PreparedStatement createEmoticonTagMappingTableStmt = """
CREATE TABLE IF NOT EXISTS $sqldbEmoticonsToTagsJoinTableName
(
  $sqldbEmoticonsId INTEGER,
  $sqldbTagId VARCHAR
)
""";
  static const PreparedStatement createEmoticonsOrderingTableStmt = """
CREATE TABLE IF NOT EXISTS $sqldbEmoticonsOrderingTableName
(
  $sqldbEmoticonsOrderingEmoticonId INTEGER,
  $sqldbEmoticonsOrderingUserOrder REAL
)
""";
  static const PreparedStatement createTagsOrderingTableStmt = """
CREATE TABLE IF NOT EXISTS $sqldbTagsOrderingTableName
(
  $sqldbTagsOrderingTagId INTEGER,
  $sqldbTagsOrderingUserOrder REAL
)
""";

  static const PreparedStatement emoticonExistsCheckStmt = """
SELECT $sqldbEmoticonsId FROM $sqldbEmoticonsTableName
WHERE $sqldbEmoticonsText=?
""";

  static const PreparedStatement emoticonInsertStmt = """
INSERT INTO $sqldbEmoticonsTableName
  ($sqldbEmoticonsText)
VALUES
  (?)
""";

  static const PreparedStatement emoticonUpdateStmt = """
UPDATE $sqldbEmoticonsTableName
SET $sqldbEmoticonsText=?
WHERE $sqldbEmoticonsId=?
""";

  static const PreparedStatement emoticonRemoveStmt = """
DELETE FROM $sqldbEmoticonsTableName
WHERE $sqldbEmoticonsId=?
""";

  static const PreparedStatement emoticonTagMapStmt = """
INSERT INTO $sqldbEmoticonsToTagsJoinTableName
  ($sqldbEmoticonsId, $sqldbTagId)
VALUES
  (?, ?)
""";

  static const PreparedStatement removeEmoticonFromJoinStmt = """
DELETE FROM $sqldbEmoticonsToTagsJoinTableName
WHERE $sqldbEmoticonsId=?
""";

  static const PreparedStatement tagExistsCheckStmt = """
SELECT 
  $sqldbTagId 
FROM 
  $sqldbTagsTableName
WHERE 
  $sqldbTagName=?
""";

  static const PreparedStatement tagInsertStmt = """
INSERT INTO $sqldbTagsTableName
  ($sqldbTagName)
VALUES
  (?)
""";

  static const PreparedStatement tagDeleteStmt = """
DELETE FROM $sqldbTagsTableName
WHERE $sqldbTagId=?
""";

  static const PreparedStatement removeTagFromJoinStmt = """
DELETE FROM $sqldbEmoticonsToTagsJoinTableName
WHERE $sqldbTagId=?
""";
}
