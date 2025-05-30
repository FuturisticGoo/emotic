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
  em.${_SQLNames.emoticonsId},
  em.${_SQLNames.emoticonsText} 
FROM 
  ${_SQLNames.emoticonsTableName} em
LEFT JOIN
  ${_SQLNames.emoticonsOrderingTableName} ord
ON
  em.${_SQLNames.emoticonsId}=ord.${_SQLNames.emoticonsOrderingEmoticonId}
ORDER BY
  ord.${_SQLNames.emoticonsOrderingUserOrder} ASC NULLS LAST,
  em.${_SQLNames.emoticonsId} ASC
""");
  for (final row in emoticonSet) {
    final emoticonId = int.parse(row[_SQLNames.emoticonsId].toString());
    final tagSet = await db.rawQuery(
      """
  SELECT tags.${_SQLNames.tagName} 
    FROM ${_SQLNames.tagsTableName} AS tags,
         ${_SQLNames.emoticonsToTagsJoinTableName} AS tagjoin
    WHERE tagjoin.${_SQLNames.emoticonsId}==?
      AND tagjoin.${_SQLNames.tagId}==tags.${_SQLNames.tagId}
""",
      [
        emoticonId,
      ],
    );
    final emoticon = Emoticon(
      id: emoticonId,
      text: row[_SQLNames.emoticonsText].toString(),
      emoticonTags: tagSet.map(
        (Map<String, Object?> row) {
          return row[_SQLNames.tagName].toString();
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
  tg.${_SQLNames.tagName} 
FROM 
  ${_SQLNames.tagsTableName} tg
LEFT JOIN
  ${_SQLNames.tagsOrderingTableName} ord
ON 
  tg.${_SQLNames.tagId}=ord.${_SQLNames.tagsOrderingTagId}
ORDER BY
  ord.${_SQLNames.tagsOrderingUserOrder} ASC NULLS LAST,
  tg.${_SQLNames.tagId} ASC
      """);
  List<String> tags = tagResultSet
      .map(
        (element) => element[_SQLNames.tagName].toString(),
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
  ${_SQLNames.emoticonsOrderingTableName}
    """);
    if (existing.single[orderCount] == 0) {
      getLogger().config("Prefilling emoticons ordering");
      await db.rawInsert("""
INSERT INTO
  ${_SQLNames.emoticonsOrderingTableName}
  (${_SQLNames.emoticonsOrderingEmoticonId}, ${_SQLNames.emoticonsOrderingUserOrder})
SELECT 
  ${_SQLNames.emoticonsId} ${_SQLNames.emoticonsOrderingEmoticonId}, 
  CAST(${_SQLNames.emoticonsId} AS REAL) ${_SQLNames.emoticonsOrderingUserOrder}
FROM
  ${_SQLNames.emoticonsTableName}
      """);
    }
  }

  Future<void> _prefillTagsOrdering() async {
    final orderCount = "order_count";
    final existing = await db.rawQuery("""
SELECT 
  COUNT(*) AS $orderCount 
FROM
  ${_SQLNames.tagsOrderingTableName}
    """);
    if (existing.single[orderCount] == 0) {
      getLogger().config("Prefilling tags ordering");
      await db.rawInsert("""
INSERT INTO
  ${_SQLNames.tagsOrderingTableName}
  (${_SQLNames.tagsOrderingTagId}, ${_SQLNames.tagsOrderingUserOrder})
SELECT 
  ${_SQLNames.tagId} ${_SQLNames.tagsOrderingTagId},
  CAST(${_SQLNames.tagId} AS REAL) ${_SQLNames.tagsOrderingUserOrder}
FROM
  ${_SQLNames.tagsTableName}
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
        emoticonId = emoticonResultSet.first[_SQLNames.emoticonsId] as int;
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
      emoticonId = emoticonResultSet.first[_SQLNames.emoticonsId] as int;
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
          int.parse(emoticonResultSet.first[_SQLNames.emoticonsId].toString());
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
  ${_SQLNames.emoticonsOrderingTableName}
WHERE
  ${_SQLNames.emoticonsOrderingEmoticonId}=?
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
  ${_SQLNames.tagsOrderingTableName}
WHERE
  ${_SQLNames.tagsOrderingTagId}=?
      """,
        [tagId],
      );
    }
  }

  @override
  Future<void> clearAllData() async {
    await db.rawDelete("DELETE FROM ${_SQLNames.emoticonsTableName}");
    await db.rawDelete("DELETE FROM ${_SQLNames.emoticonsToTagsJoinTableName}");
    await db.rawDelete("DELETE FROM ${_SQLNames.tagsTableName}");
    await db.rawDelete("DELETE FROM ${_SQLNames.emoticonsOrderingTableName}");
    await db.rawDelete("DELETE FROM ${_SQLNames.tagsOrderingTableName}");
  }

  Future<void> _appendToEmoticonsOrder({
    required int emoticonId,
  }) async {
    final currentHighestOrder = (await getCurrentMinAndMaxOrder(
      db: db,
      tableName: _SQLNames.emoticonsOrderingTableName,
      orderColumnName: _SQLNames.emoticonsOrderingUserOrder,
    ))
        ?.$2;
    await db.rawInsert(
      """
INSERT INTO
  ${_SQLNames.emoticonsOrderingTableName}
  (${_SQLNames.emoticonsOrderingEmoticonId}, ${_SQLNames.emoticonsOrderingUserOrder})
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
      tableName: _SQLNames.tagsOrderingTableName,
      orderColumnName: _SQLNames.tagsOrderingUserOrder,
    ))
        ?.$2;
    await db.rawInsert(
      """
INSERT INTO
  ${_SQLNames.tagsOrderingTableName}
  (${_SQLNames.tagsOrderingTagId}, ${_SQLNames.tagsOrderingUserOrder})
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
  ${_SQLNames.emoticonsOrderingTableName}
WHERE
  ${_SQLNames.emoticonsOrderingEmoticonId}=?
      """,
      [emoticon.id],
    );

    final nMinus1AndNthValue = await getNMinus1thAndNthOrderValue(
      db: db,
      tableName: _SQLNames.emoticonsOrderingTableName,
      orderColumnName: _SQLNames.emoticonsOrderingUserOrder,
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
  ${_SQLNames.emoticonsOrderingTableName}
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
      return tagResult.firstOrNull?[_SQLNames.tagId] as int?;
    } else {
      return tagResult.first[_SQLNames.tagId] as int;
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
  ${_SQLNames.tagsOrderingTableName}
WHERE
  ${_SQLNames.tagsOrderingTagId}=?
      """,
      [tagId],
    );

    final nMinus1AndNthValue = await getNMinus1thAndNthOrderValue(
      db: db,
      tableName: _SQLNames.tagsOrderingTableName,
      orderColumnName: _SQLNames.tagsOrderingUserOrder,
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
  ${_SQLNames.tagsOrderingTableName}
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
CREATE TABLE IF NOT EXISTS ${_SQLNames.emoticonsTableName} 
(
  ${_SQLNames.emoticonsId} INTEGER PRIMARY KEY,
  ${_SQLNames.emoticonsText} VARCHAR
)
""";

  static const PreparedStatement createTagsTableStmt = """
CREATE TABLE IF NOT EXISTS ${_SQLNames.tagsTableName}
(
  ${_SQLNames.tagId} INTEGER PRIMARY KEY,
  ${_SQLNames.tagName} VARCHAR
)
""";

  static const PreparedStatement createEmoticonTagMappingTableStmt = """
CREATE TABLE IF NOT EXISTS ${_SQLNames.emoticonsToTagsJoinTableName}
(
  ${_SQLNames.emoticonsId} INTEGER,
  ${_SQLNames.tagId} VARCHAR
)
""";
  static const PreparedStatement createEmoticonsOrderingTableStmt = """
CREATE TABLE IF NOT EXISTS ${_SQLNames.emoticonsOrderingTableName}
(
  ${_SQLNames.emoticonsOrderingEmoticonId} INTEGER,
  ${_SQLNames.emoticonsOrderingUserOrder} REAL
)
""";
  static const PreparedStatement createTagsOrderingTableStmt = """
CREATE TABLE IF NOT EXISTS ${_SQLNames.tagsOrderingTableName}
(
  ${_SQLNames.tagsOrderingTagId} INTEGER,
  ${_SQLNames.tagsOrderingUserOrder} REAL
)
""";

  static const PreparedStatement emoticonExistsCheckStmt = """
SELECT ${_SQLNames.emoticonsId} FROM ${_SQLNames.emoticonsTableName}
WHERE ${_SQLNames.emoticonsText}=?
""";

  static const PreparedStatement emoticonInsertStmt = """
INSERT INTO ${_SQLNames.emoticonsTableName}
  (${_SQLNames.emoticonsText})
VALUES
  (?)
""";

  static const PreparedStatement emoticonUpdateStmt = """
UPDATE ${_SQLNames.emoticonsTableName}
SET ${_SQLNames.emoticonsText}=?
WHERE ${_SQLNames.emoticonsId}=?
""";

  static const PreparedStatement emoticonRemoveStmt = """
DELETE FROM ${_SQLNames.emoticonsTableName}
WHERE ${_SQLNames.emoticonsId}=?
""";

  static const PreparedStatement emoticonTagMapStmt = """
INSERT INTO ${_SQLNames.emoticonsToTagsJoinTableName}
  (${_SQLNames.emoticonsId}, ${_SQLNames.tagId})
VALUES
  (?, ?)
""";

  static const PreparedStatement removeEmoticonFromJoinStmt = """
DELETE FROM ${_SQLNames.emoticonsToTagsJoinTableName}
WHERE ${_SQLNames.emoticonsId}=?
""";

  static const PreparedStatement tagExistsCheckStmt = """
SELECT 
  ${_SQLNames.tagId} 
FROM 
  ${_SQLNames.tagsTableName}
WHERE 
  ${_SQLNames.tagName}=?
""";

  static const PreparedStatement tagInsertStmt = """
INSERT INTO ${_SQLNames.tagsTableName}
  (${_SQLNames.tagName})
VALUES
  (?)
""";

  static const PreparedStatement tagDeleteStmt = """
DELETE FROM ${_SQLNames.tagsTableName}
WHERE ${_SQLNames.tagId}=?
""";

  static const PreparedStatement removeTagFromJoinStmt = """
DELETE FROM ${_SQLNames.emoticonsToTagsJoinTableName}
WHERE ${_SQLNames.tagId}=?
""";
}

abstract final class _SQLNames {
  static const emoticonsTableName = "emoticons";
  static const emoticonsId = "id";
  static const emoticonsText = "text";

  static const tagsTableName = "tags";
  static const tagId = "tag_id";
  static const tagName = "tag_name";

  static const emoticonsToTagsJoinTableName = "emoticon_to_tags";

  static const emoticonsOrderingTableName = "emoticons_ordering";
  static const emoticonsOrderingEmoticonId = "emoticon_id";
  static const emoticonsOrderingUserOrder = "emoticon_user_order";

  static const tagsOrderingTableName = "tags_ordering";
  static const tagsOrderingTagId = "tag_id";
  static const tagsOrderingUserOrder = "tag_user_order";
}
