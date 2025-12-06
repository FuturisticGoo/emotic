import 'package:emotic/core/entities/emoticon.dart';
import 'package:emotic/core/entities/semver.dart';
import 'package:emotic/data/emoticons_source.dart';

class EmoticonsRepository {
  final EmoticonsSource database;

  EmoticonsRepository({
    required this.database,
  });
  Future<List<Emoticon>> getEmoticons({
    SemVer? filterVersionFromAsset,
    SemVer? filterVersionFromDatabase,
  }) async {
    return database.getEmoticons(
      filterVersion: filterVersionFromDatabase,
    );
  }

  Future<void> saveEmoticon({
    required NewOrModifyEmoticon newOrModifyEmoticon,
  }) async {
    await database.saveEmoticon(newOrModifyEmoticon: newOrModifyEmoticon);
  }

  Future<void> deleteEmoticon({
    required Emoticon emoticon,
  }) async {
    await database.deleteEmoticon(emoticon: emoticon);
  }

  Future<List<String>> getTags() async {
    return database.getTags();
  }

  Future<void> saveTag({required String tag}) async {
    return database.saveTag(tag: tag);
  }

  Future<void> deleteTag({required String tag}) async {
    return database.deleteTag(tag: tag);
  }

  Future<void> clearAllData() async {
    return database.clearAllData();
  }

  Future<void> modifyEmoticonOrder({
    required Emoticon emoticon,
    required int newOrder,
  }) async {
    return database.modifyEmoticonOrder(
      emoticon: emoticon,
      newOrder: newOrder,
    );
  }

  Future<void> modifyTagOrder({
    required String tag,
    required int newOrder,
  }) async {
    return database.modifyTagOrder(
      tag: tag,
      newOrder: newOrder,
    );
  }
}
