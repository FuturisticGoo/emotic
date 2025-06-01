import 'package:emotic/core/logging.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:emotic/data/emoticons_source.dart';
import 'package:emotic/data/image_source.dart';
import 'package:emotic/data/settings_source.dart';
import 'package:fpdart/fpdart.dart';

class SettingsRepository {
  final EmoticonsSource emoticonsSource;
  final ImageSource imageSource;
  final SettingsSource settingsSource;
  const SettingsRepository({
    required this.settingsSource,
    required this.emoticonsSource,
    required this.imageSource,
  });

  Future<Either<Failure, Success>> importFromFile() async {
    try {
      final importBundle = await settingsSource.importFromFile();
      if (emoticonsSource is EmoticonsSqliteSource) {
        await (emoticonsSource as EmoticonsSqliteSource).importFromDb(
          importDb: importBundle.db,
          importStrategy: ImportStrategy.merge,
        );
      }
      if (imageSource is ImageSourceSQLiteAndFS) {
        await (imageSource as ImageSourceSQLiteAndFS).importFromDb(
          importReader: importBundle.importReader,
          importDb: importBundle.db,
        );
      }
      await importBundle.onImportFinish();
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      getLogger().severe("Error importing", error, stackTrace);
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> exportToFile() async {
    try {
      final exportBundle = await settingsSource.exportToFile();
      if (emoticonsSource is EmoticonsSqliteSource) {
        await (emoticonsSource as EmoticonsSqliteSource).exportToDb(
          exportDb: exportBundle.db,
        );
      }
      getLogger().config("Finished emoticons");
      if (imageSource is ImageSourceSQLiteAndFS) {
        await (imageSource as ImageSourceSQLiteAndFS).exportToDb(
          exportDb: exportBundle.db,
          exportWriter: exportBundle.exportWriter,
        );
      }
      getLogger().config("Finished emotipics");
      await exportBundle.finishExport();
      getLogger().config("Finished writing");
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      getLogger().severe("Error exporting", error, stackTrace);
      return Either.left(GenericFailure(error, stackTrace));
    }
  }
}
