import 'package:emotic/core/emoticon.dart';
import 'package:emotic/data/emoticons_source.dart';

class EmoticonsRepository {
  final EmoticonsSource assetSource;
  final EmoticonsSource database;

  EmoticonsRepository({
    required this.assetSource,
    required this.database,
  });
  Future<void> _loadEmoticonsToDatabase() async {
    final emoticons = await assetSource.getEmoticons();
    await database.saveEmoticons(emoticons: emoticons);
  }

  Future<List<Emoticon>> getEmoticons({
    required bool shouldLoadFromAsset,
  }) async {
    if (shouldLoadFromAsset) {
      await _loadEmoticonsToDatabase();
    }
    return database.getEmoticons();
  }

  Future<void> saveEmoticon({required Emoticon emoticon}) async {
    await database.saveEmoticons(emoticons: [emoticon]);
  }
}
