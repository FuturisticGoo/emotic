import 'package:emotic/core/emoticon.dart';
import 'package:emotic/data/emoticons_source.dart';

class EmoticonsRepository {
  final EmoticonsSource assetSource;
  final EmoticonsStore database;

  EmoticonsRepository({
    required this.assetSource,
    required this.database,
  });
  Future<void> _loadEmoticonsToDatabase() async {
    final emoticons = await assetSource.getEmoticons();
    for (final emoticon in emoticons) {
      await database.saveEmoticon(emoticon: emoticon);
    }
  }

  Future<List<Emoticon>> getEmoticons({
    required bool shouldLoadFromAsset,
  }) async {
    if (shouldLoadFromAsset) {
      await _loadEmoticonsToDatabase();
    }
    return database.getEmoticons();
  }

  Future<void> saveEmoticon({
    required Emoticon emoticon,
    Emoticon? oldEmoticon,
  }) async {
    await database.saveEmoticon(
      emoticon: emoticon,
      oldEmoticon: oldEmoticon,
    );
  }

  Future<void> deleteEmoticon({required Emoticon emoticon}) async {
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
}
