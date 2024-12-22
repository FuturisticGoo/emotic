import 'dart:developer';
import 'dart:io' as io;
import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/emoticon.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

enum ImportStrategy { merge, overwrite }

abstract class EmoticonsSource {
  Future<List<Emoticon>> getEmoticons();
  Future<List<String>> getTags();
}

abstract class EmoticonsStore extends EmoticonsSource {
  Future<void> saveEmoticon({
    required Emoticon emoticon,
    Emoticon? oldEmoticon,
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
}

Future<List<Emoticon>> _getEmoticonsFromDb({required Database db}) async {
  List<Emoticon> emoticons = [];
  final emoticonSet = await db.rawQuery("""
  SELECT $sqldbEmoticonsId, $sqldbEmoticonsText FROM $sqldbEmoticonsTableName
""");
  for (final row in emoticonSet) {
    final emoticonId = int.parse(row[sqldbEmoticonsId].toString());
    final tagSet = await db.rawQuery(
      """
  SELECT tags.$sqldbTagName 
    FROM $sqldbTagsTableName AS tags,
         $sqldbEmoticonsToTagsJoinTableName AS tagjoin
    WHERE tagjoin.$sqldbEmoticonsId==?
      AND tagjoin.$sqldbTagsId==tags.$sqldbTagsId
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
  final tagResultSet =
      await db.rawQuery("""SELECT $sqldbTagName FROM $sqldbTagsTableName""");
  List<String> tags = tagResultSet
      .map(
        (element) => element[sqldbTagName].toString(),
      )
      .toList();
  return tags;
}

class EmoticonsSourceAssetDB implements EmoticonsSource {
  final AssetBundle assetBundle;
  EmoticonsSourceAssetDB({
    required this.assetBundle,
  });
  Database? sourceDb;
  io.File? dbFile;

  Future<void> copyDbFromAsset() async {
    if (sourceDb == null) {
      final sourceDbFile = await assetBundle.load(emoticonsSourceDbAsset);
      final appDataPath = await getApplicationDocumentsDirectory();
      dbFile = io.File(p.join(appDataPath.path, emoticonsSourceDbName));
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
    await copyDbFromAsset();
    return _getEmoticonsFromDb(db: sourceDb!);
  }

  @override
  Future<List<String>> getTags() async {
    await copyDbFromAsset();
    return _getTagsFromDb(db: sourceDb!);
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
  $sqldbTagsId INTEGER PRIMARY KEY,
  $sqldbTagName VARCHAR
)
""";

  static const PreparedStatement createEmoticonTagMappingTableStmt = """
CREATE TABLE IF NOT EXISTS $sqldbEmoticonsToTagsJoinTableName
(
  $sqldbEmoticonsId INTEGER,
  $sqldbTagsId VARCHAR
)
""";

  static const PreparedStatement emoticonExistsCheckStmt = """
SELECT $sqldbEmoticonsId FROM $sqldbEmoticonsTableName
WHERE $sqldbEmoticonsText==?
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
WHERE $sqldbEmoticonsId==?
""";

  static const PreparedStatement emoticonRemoveStmt = """
DELETE FROM $sqldbEmoticonsTableName
WHERE $sqldbEmoticonsId==?
""";

  static const PreparedStatement emoticonTagMapStmt = """
INSERT INTO $sqldbEmoticonsToTagsJoinTableName
  ($sqldbEmoticonsId, $sqldbTagsId)
VALUES
  (?, ?)
""";

  static const PreparedStatement removeEmoticonFromJoinStmt = """
DELETE FROM $sqldbEmoticonsToTagsJoinTableName
WHERE $sqldbEmoticonsId==?
""";

  static const PreparedStatement tagExistsCheckStmt = """
SELECT $sqldbTagsId FROM $sqldbTagsTableName
WHERE $sqldbTagName==?
""";

  static const PreparedStatement tagInsertStmt = """
INSERT INTO $sqldbTagsTableName
  ($sqldbTagName)
VALUES
  (?)
""";

  static const PreparedStatement tagDeleteStmt = """
DELETE FROM $sqldbTagsTableName
WHERE $sqldbTagsId==?
""";

  static const PreparedStatement removeTagFromJoinStmt = """
DELETE FROM $sqldbEmoticonsToTagsJoinTableName
WHERE $sqldbTagsId==?
""";
}

class EmoticonsSqliteSource implements EmoticonsStore {
  final Database db;

  EmoticonsSqliteSource({required this.db}) {
    _ensureTables();
  }

  Future<void> _ensureTables() async {
    await db.execute(SQLStatements.createEmoticonTableStmt);
    await db.execute(SQLStatements.createTagsTableStmt);
    await db.execute(SQLStatements.createEmoticonTagMappingTableStmt);
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
    required Emoticon emoticon,
    Emoticon? oldEmoticon,
  }) async {
    int emoticonId;
    if (oldEmoticon == null) {
      final emoticonResultSet = await db.rawQuery(
        SQLStatements.emoticonExistsCheckStmt,
        [emoticon.text],
      );
      if (emoticonResultSet.isEmpty) {
        // Only inserting if its not there
        await db.execute(SQLStatements.emoticonInsertStmt, [emoticon.text]);
        emoticonId = (await db.rawQuery('SELECT last_insert_rowid()'))
            .first
            .values
            .first as int;
      } else {
        emoticonId = int.parse(
          emoticonResultSet.first[sqldbEmoticonsId].toString(),
        );
      }
    } else {
      final emoticonResultSet = await db.rawQuery(
        SQLStatements.emoticonExistsCheckStmt,
        [emoticon.text],
      );
      if (emoticonResultSet.length != 1) {
        log("Got ${emoticonResultSet.length} length result when checking emoticonExistsCheckStmt in saveEmoticon");
      }
      emoticonId =
          int.parse(emoticonResultSet.first[sqldbEmoticonsId].toString());
      await db.execute(
          SQLStatements.emoticonUpdateStmt, [emoticon.text, emoticonId]);
    }
    await db.execute(SQLStatements.removeEmoticonFromJoinStmt, [emoticonId]);

    // Its easier this way
    for (final tag in emoticon.emoticonTags) {
      await saveTag(tag: tag);
      final tagResultSet = await db.rawQuery(
        SQLStatements.tagExistsCheckStmt,
        [tag],
      );
      if (tagResultSet.length != 1) {
        log("Got ${tagResultSet.length} length result when checking tagExistsCheckStmt in saveEmoticon");
      }
      int tagId = int.parse(tagResultSet.first[sqldbTagsId].toString());
      await db.execute(SQLStatements.emoticonTagMapStmt, [emoticonId, tagId]);
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
        log("Got ${emoticonResultSet.length} length result when checking emoticonExistsCheckStmt in deleteEmoticon");
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
    }
  }

  @override
  Future<void> saveTag({required String tag}) async {
    final tagResultSet = await db.rawQuery(
      SQLStatements.tagExistsCheckStmt,
      [tag],
    );
    if (tagResultSet.isEmpty) {
      await db.execute(
        SQLStatements.tagInsertStmt,
        [tag],
      );
    }
  }

  @override
  Future<void> deleteTag({required String tag}) async {
    final tagResultSet = await db.rawQuery(
      SQLStatements.tagExistsCheckStmt,
      [tag],
    );
    if (tagResultSet.isNotEmpty) {
      int tagId = int.parse(tagResultSet.single[sqldbTagsId].toString());
      await db.execute(
        SQLStatements.tagDeleteStmt,
        [tagId],
      );
      await db.execute(
        SQLStatements.removeTagFromJoinStmt,
        [tagId],
      );
    }
  }

  @override
  Future<void> clearAllData() async {
    await db.rawDelete("DELETE FROM $sqldbEmoticonsTableName");
    await db.rawDelete("DELETE FROM $sqldbEmoticonsToTagsJoinTableName");
    await db.rawDelete("DELETE FROM $sqldbTagsTableName");
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
      final emoticonSet = await sourceDb.rawQuery("""
  SELECT $sqldbEmoticonsId, $sqldbEmoticonsText FROM $sqldbEmoticonsTableName
""");
      switch (importStrategy) {
        case ImportStrategy.overwrite:
          await clearAllData();
          continue merge;
        merge:
        case ImportStrategy.merge:
          for (final row in emoticonSet) {
            final emoticonId = int.parse(row[sqldbEmoticonsId].toString());
            final tagSet = await sourceDb.rawQuery(
              """
  SELECT tags.$sqldbTagName 
    FROM $sqldbTagsTableName AS tags,
         $sqldbEmoticonsToTagsJoinTableName AS tagjoin
    WHERE tagjoin.$sqldbEmoticonsId==?
      AND tagjoin.$sqldbTagsId==tags.$sqldbTagsId
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
            await saveEmoticon(emoticon: emoticon);
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
      final cacheDir = await getApplicationCacheDirectory();

      final outputDbPath = p.join(cacheDir.path, fileName);
      await db.execute("VACUUM");
      await io.File(db.path).copy(outputDbPath);
      final outputDb = await openDatabase(outputDbPath);
      await outputDb.execute("""DROP TABLE $sqldbSettingsTableName""");
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
