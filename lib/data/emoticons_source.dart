import 'dart:developer';
import 'dart:io' as io;
import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/emoticon.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:file_picker/file_picker.dart';

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
  final emoticonSet = db.select("""
  SELECT $sqldbEmoticonsId, $sqldbEmoticonsText FROM $sqldbEmoticonsTableName
""");
  for (final row in emoticonSet) {
    final emoticonId = row[sqldbEmoticonsId];
    final tagSet = db.select(
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
      text: row[sqldbEmoticonsText],
      emoticonTags: tagSet.map(
        (Row row) {
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
      db.select("""SELECT $sqldbTagName FROM $sqldbTagsTableName""");
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
      sourceDb = sqlite3.open(dbFile!.path);
    }
  }

  Future<void> dispose() async {
    sourceDb?.dispose();
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

class EmoticonsSqliteSource implements EmoticonsStore {
  final Database db;
  late final PreparedStatement createEmoticonTableStmt;
  late final PreparedStatement createTagsTableStmt;
  late final PreparedStatement createEmoticonTagMappingTableStmt;

  late final PreparedStatement emoticonExistsCheckStmt;
  late final PreparedStatement emoticonInsertStmt;
  late final PreparedStatement emoticonUpdateStmt;
  late final PreparedStatement emoticonRemoveStmt;
  late final PreparedStatement emoticonTagMapStmt;
  late final PreparedStatement removeEmoticonFromJoinStmt;

  late final PreparedStatement tagExistsCheckStmt;
  late final PreparedStatement tagInsertStmt;
  late final PreparedStatement tagDeleteStmt;
  late final PreparedStatement removeTagFromJoinStmt;

  EmoticonsSqliteSource({required this.db}) {
    createEmoticonTableStmt = db.prepare("""
CREATE TABLE IF NOT EXISTS $sqldbEmoticonsTableName 
(
  $sqldbEmoticonsId INTEGER PRIMARY KEY,
  $sqldbEmoticonsText VARCHAR
)
""");

    createTagsTableStmt = db.prepare("""
CREATE TABLE IF NOT EXISTS $sqldbTagsTableName
(
  $sqldbTagsId INTEGER PRIMARY KEY,
  $sqldbTagName VARCHAR
)
""");

    createEmoticonTagMappingTableStmt = db.prepare("""
CREATE TABLE IF NOT EXISTS $sqldbEmoticonsToTagsJoinTableName
(
  $sqldbEmoticonsId INTEGER,
  $sqldbTagsId VARCHAR
)
""");

    _ensureTables();

    emoticonExistsCheckStmt = db.prepare("""
SELECT $sqldbEmoticonsId FROM $sqldbEmoticonsTableName
WHERE $sqldbEmoticonsText==?
""");
    emoticonInsertStmt = db.prepare("""
INSERT INTO $sqldbEmoticonsTableName
  ($sqldbEmoticonsText)
VALUES
  (?)
""");
    emoticonUpdateStmt = db.prepare("""
UPDATE $sqldbEmoticonsTableName
SET $sqldbEmoticonsText=?
WHERE $sqldbEmoticonsId==?
""");
    emoticonRemoveStmt = db.prepare("""
DELETE FROM $sqldbEmoticonsTableName
WHERE $sqldbEmoticonsId==?
""");
    emoticonTagMapStmt = db.prepare("""
INSERT INTO $sqldbEmoticonsToTagsJoinTableName
  ($sqldbEmoticonsId, $sqldbTagsId)
VALUES
  (?, ?)
""");
    removeEmoticonFromJoinStmt = db.prepare("""
DELETE FROM $sqldbEmoticonsToTagsJoinTableName
WHERE $sqldbEmoticonsId==?
""");

    tagExistsCheckStmt = db.prepare("""
SELECT $sqldbTagsId FROM $sqldbTagsTableName
WHERE $sqldbTagName==?
""");
    tagInsertStmt = db.prepare("""
INSERT INTO $sqldbTagsTableName
  ($sqldbTagName)
VALUES
  (?)
""");
    tagDeleteStmt = db.prepare("""
DELETE FROM $sqldbTagsTableName
WHERE $sqldbTagsId==?
""");
    removeTagFromJoinStmt = db.prepare("""
DELETE FROM $sqldbEmoticonsToTagsJoinTableName
WHERE $sqldbTagsId==?
""");
  }

  Future<void> dispose() async {
    createEmoticonTableStmt.dispose();
    createTagsTableStmt.dispose();
    createEmoticonTagMappingTableStmt.dispose();

    emoticonExistsCheckStmt.dispose();
    emoticonInsertStmt.dispose();
    emoticonUpdateStmt.dispose();
    emoticonRemoveStmt.dispose();
    emoticonTagMapStmt.dispose();
    removeEmoticonFromJoinStmt.dispose();

    tagExistsCheckStmt.dispose();
    tagInsertStmt.dispose();
    tagDeleteStmt.dispose();
    removeTagFromJoinStmt.dispose();
  }

  void _ensureTables() {
    createEmoticonTableStmt.execute();
    createTagsTableStmt.execute();
    createEmoticonTagMappingTableStmt.execute();
  }

  @override
  Future<List<String>> getTags() async {
    return _getTagsFromDb(db: db);
  }

  @override
  Future<List<Emoticon>> getEmoticons() async {
    _ensureTables();
    return _getEmoticonsFromDb(db: db);
  }

  @override
  Future<void> saveEmoticon({
    required Emoticon emoticon,
    Emoticon? oldEmoticon,
  }) async {
    int emoticonId;
    if (oldEmoticon == null) {
      final emoticonResultSet = emoticonExistsCheckStmt.select(
        [emoticon.text],
      );
      if (emoticonResultSet.isEmpty) {
        // Only inserting if its not there
        emoticonInsertStmt.execute([emoticon.text]);
        emoticonId = db.lastInsertRowId;
      } else {
        emoticonId = emoticonResultSet.first[sqldbEmoticonsId];
      }
    } else {
      final emoticonResultSet = emoticonExistsCheckStmt.select(
        [emoticon.text],
      );
      if (emoticonResultSet.length != 1) {
        log("Got ${emoticonResultSet.length} length result when checking emoticonExistsCheckStmt in saveEmoticon");
      }
      emoticonId = emoticonResultSet.first[sqldbEmoticonsId];
      emoticonUpdateStmt.execute([emoticon.text, emoticonId]);
    }
    removeEmoticonFromJoinStmt.execute([emoticonId]);
    // Its easier this way
    for (final tag in emoticon.emoticonTags) {
      await saveTag(tag: tag);
      final tagResultSet = tagExistsCheckStmt.select([tag]);
      if (tagResultSet.length != 1) {
        log("Got ${tagResultSet.length} length result when checking tagExistsCheckStmt in saveEmoticon");
      }
      int tagId = tagResultSet.first[sqldbTagsId];
      emoticonTagMapStmt.execute([emoticonId, tagId]);
    }
  }

  @override
  Future<void> deleteEmoticon({required Emoticon emoticon}) async {
    final emoticonResultSet = emoticonExistsCheckStmt.select(
      [emoticon.text],
    );
    if (emoticonResultSet.isNotEmpty) {
      if (emoticonResultSet.length != 1) {
        log("Got ${emoticonResultSet.length} length result when checking emoticonExistsCheckStmt in deleteEmoticon");
      }
      final emoticonIdToRemove = emoticonResultSet.first[sqldbEmoticonsId];
      emoticonRemoveStmt.execute([emoticonIdToRemove]);
      removeEmoticonFromJoinStmt.execute([emoticonIdToRemove]);
    }
  }

  @override
  Future<void> saveTag({required String tag}) async {
    final tagResultSet = tagExistsCheckStmt.select([tag]);
    if (tagResultSet.isEmpty) {
      tagInsertStmt.execute([tag]);
    }
  }

  @override
  Future<void> deleteTag({required String tag}) async {
    final tagResultSet = tagExistsCheckStmt.select([tag]);
    if (tagResultSet.isNotEmpty) {
      int tagId = tagResultSet.single[sqldbTagsId];
      tagDeleteStmt.execute([tagId]);
      removeTagFromJoinStmt.execute([tagId]);
    }
  }

  @override
  Future<void> clearAllData() async {
    db.execute("DELETE FROM $sqldbEmoticonsTableName");
    db.execute("DELETE FROM $sqldbEmoticonsToTagsJoinTableName");
    db.execute("DELETE FROM $sqldbTagsTableName");
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
      Database sourceDb = sqlite3.open(dbPath);
      final emoticonSet = sourceDb.select("""
  SELECT $sqldbEmoticonsId, $sqldbEmoticonsText FROM $sqldbEmoticonsTableName
""");
      switch (importStrategy) {
        case ImportStrategy.overwrite:
          await clearAllData();
          continue merge;
        merge:
        case ImportStrategy.merge:
          for (final row in emoticonSet) {
            final emoticonId = row[sqldbEmoticonsId];
            final tagSet = sourceDb.select(
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
              text: row[sqldbEmoticonsText],
              emoticonTags: tagSet.map(
                (Row row) {
                  return row[sqldbTagName].toString();
                },
              ).toList(),
            );
            await saveEmoticon(emoticon: emoticon);
          }
      }
      sourceDb.dispose();
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
      final outputDb = sqlite3.open(outputDbPath);
      await db.backup(outputDb).drain();
      outputDb.execute("""DROP TABLE $sqldbSettingsTableName""");
      outputDb.dispose();
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
