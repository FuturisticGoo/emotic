import 'dart:convert';

import 'package:emotic/core/constants.dart';
import 'package:emotic/core/emoticon.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

abstract class EmoticonsSource {
  Future<List<Emoticon>> getEmoticons();
  Future<void> saveEmoticons({required List<Emoticon> emoticons});
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
  Future<void> saveEmoticons({required List<Emoticon> emoticons}) {
    throw AssertionError("saveEmoticon should not be called on Asset source");
  }
}

/*
class EmoticonsHiveSource implements EmoticonsSource {
  final Box box;
  const EmoticonsHiveSource({
    required this.box,
  });

  @override
  Future<List<Emoticon>> getEmoticons() async {
    var emoticonsMap = box.toMap();
    emoticonsMap.remove(isFirstTimeKey);
    List<Emoticon> emoticons = [];
    for (final value in emoticonsMap.values) {
      final json = Map<String, dynamic>.from(value);
      emoticons.add(Emoticon.fromJson(json));
    }
    return emoticons;
  }

  @override
  Future<void> saveEmoticons({required List<Emoticon> emoticons}) async {
    var emoticonsMap = box.toMap();
    emoticonsMap.remove(isFirstTimeKey);
    var idList = List<int>.from(emoticonsMap.keys);
    var lastIndex = idList.fold(0, max);

    for (final emoticon in emoticons) {
      final id = emoticon.id ?? (++lastIndex);
      await box.put(
        id,
        Emoticon(
          id: id,
          text: emoticon.text,
          emoticonTags: emoticon.emoticonTags,
        ).toJson(),
      );
    }
  }
}
*/
class EmoticonsSqliteSource implements EmoticonsSource {
  final Database db;
  late final PreparedStatement createEmoticonTableStmt;
  late final PreparedStatement createTagsTableStmt;
  late final PreparedStatement createEmoticonTagMappingTableStmt;
  late final PreparedStatement emoticonExistsCheckStmt;
  late final PreparedStatement emoticonInsertStmt;
  late final PreparedStatement emoticonRemoveStmt;
  late final PreparedStatement removeAllTagsStmt;
  late final PreparedStatement tagExistsCheckStmt;
  late final PreparedStatement tagInsertStmt;
  late final PreparedStatement emoticonTagMapStmt;
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
    emoticonRemoveStmt = db.prepare("""
DELETE FROM $sqldbEmoticonsTableName
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
    emoticonTagMapStmt = db.prepare("""
INSERT INTO $sqldbEmoticonsToTagsJoinTableName
  ($sqldbEmoticonsId, $sqldbTagsId)
VALUES
  (?, ?)
""");
    removeAllTagsStmt = db.prepare("""
DELETE FROM $sqldbEmoticonsToTagsJoinTableName
WHERE $sqldbEmoticonsId==?
""");
  }

  Future<void> dispose() async {
    createEmoticonTableStmt.dispose();
    createTagsTableStmt.dispose();
    createEmoticonTagMappingTableStmt.dispose();
    emoticonExistsCheckStmt.dispose();
    emoticonInsertStmt.dispose();
    emoticonRemoveStmt.dispose();
    removeAllTagsStmt.dispose();
    tagExistsCheckStmt.dispose();
    tagInsertStmt.dispose();
    emoticonTagMapStmt.dispose();
  }

  void _ensureTables() {
    createEmoticonTableStmt.execute();
    createTagsTableStmt.execute();
    createEmoticonTagMappingTableStmt.execute();
  }

  Future<void> _saveEmoticon({
    required Emoticon emoticon,
    Emoticon? oldEmoticon, // In case of update
  }) async {
    int emoticonId;
    // If the emoticon already exists in table (ie, to update or merge)
    final emoticonText = oldEmoticon?.text ?? emoticon.text;
    final emoticonResultSet = emoticonExistsCheckStmt.select(
      [emoticonText],
    );

    if (emoticonResultSet.isNotEmpty) {
      // Remove that emoticon, because its easier this way
      final emoticonIdToRemove = emoticonResultSet.single[sqldbEmoticonsId];
      emoticonRemoveStmt.execute([emoticonIdToRemove]);
      removeAllTagsStmt.execute([emoticonIdToRemove]);
    }
    emoticonInsertStmt.execute([emoticon.text]);
    emoticonId = db.lastInsertRowId;

    // Before inserting tags and or updating, just remove all the existing
    // mapping since its just easier to insert again than check for duplicates

    for (final tag in emoticon.emoticonTags) {
      int tagId;
      final tagResultSet = tagExistsCheckStmt.select([tag]);
      if (tagResultSet.isNotEmpty) {
        tagId = tagResultSet.first[sqldbTagsId];
      } else {
        tagInsertStmt.execute([tag]);
        tagId = db.lastInsertRowId;
      }
      emoticonTagMapStmt.execute([emoticonId, tagId]);
    }
  }

  @override
  Future<void> saveEmoticons({required List<Emoticon> emoticons}) async {
    _ensureTables();
    for (final emoticon in emoticons) {
      await _saveEmoticon(emoticon: emoticon);
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
