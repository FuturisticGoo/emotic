import 'dart:convert';
import 'dart:developer';

import 'package:emotic/core/constants.dart';
import 'package:emotic/core/emoticon.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

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
}

class EmoticonsSourceAssetBundle implements EmoticonsSource {
  final AssetBundle assetBundle;
  EmoticonsSourceAssetBundle({required this.assetBundle});
  @override
  Future<List<Emoticon>> getEmoticons() async {
    List<Emoticon> emoticons = [];

    final emoticonsCsvString =
        await assetBundle.loadString(emoticonsCsvAssetKey);
    final emoticonDataFrame = CsvCodec(
      shouldParseNumbers: false,
      eol: "\n",
      textDelimiter: emoticonsCsvStringDelimiter,
    ).decoder.convert(emoticonsCsvString).sublist(1);

    final emoticonTagsJsonString =
        await assetBundle.loadString(emoticonsTagJsonAssetKey);
    final emoticonTagMapUncasted =
        Map<String, dynamic>.from(jsonDecode(emoticonTagsJsonString));
    var emoticonTagMap = <String, List<String>>{};
    for (final entry in emoticonTagMapUncasted.entries) {
      emoticonTagMap[entry.key] = (entry.value as List)
          .map(
            (e) => e.toString(),
          )
          .toList();
    }
    for (final emoticonRow in emoticonDataFrame) {
      emoticons.add(
        Emoticon(
          id: int.parse(emoticonRow[0]),
          text: emoticonRow[1],
          emoticonTags: emoticonTagMap.entries
              .where(
                // Getting all the tags of this emoticon
                (tagEntry) => tagEntry.value.contains(emoticonRow[0]),
              )
              .map(
                // Getting that tag name
                (matchedTag) => matchedTag.key,
              )
              .toList(),
        ),
      );
    }
    return emoticons;
  }

  @override
  Future<List<String>> getTags() async {
    final emoticons = await getEmoticons();
    Set<String> tags = {};
    for (final emoticon in emoticons) {
      tags.addAll(emoticon.emoticonTags);
    }
    return tags.toList();
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
  Future<void> saveEmoticon({
    required Emoticon emoticon,
    Emoticon? oldEmoticon,
  }) async {
    int emoticonId;
    if (oldEmoticon == null) {
      emoticonInsertStmt.execute([emoticon.text]);
      emoticonId = db.lastInsertRowId;
    } else {
      final emoticonResultSet = emoticonExistsCheckStmt.select(
        [emoticon.text],
      );
      // if (emoticonResultSet.isNotEmpty) {
      if (emoticonResultSet.length != 1) {
        log("Got ${emoticonResultSet.length} length result when checking emoticonExistsCheckStmt in saveEmoticon");
      }
      emoticonId = emoticonResultSet.first[sqldbEmoticonsId];
      // }
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
  Future<List<String>> getTags() async {
    final tagResultSet =
        db.select("""SELECT $sqldbTagName FROM $sqldbTagsTableName""");
    List<String> tags = tagResultSet
        .map(
          (element) => element[sqldbTagName].toString(),
        )
        .toList();
    return tags;
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
  Future<List<Emoticon>> getEmoticons() async {
    _ensureTables();
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
}
