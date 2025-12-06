import 'package:emotic/core/export_config.dart';
import 'package:emotic/core/helper_functions.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/entities/status_entities.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/data/emoticons_source.dart';
import 'package:emotic/data/image_source.dart';
import 'package:emotic/data/settings_source.dart';
import 'package:fpdart/fpdart.dart';

class SettingsRepository {
  final EmoticonsSource emoticonsSource;
  final ImageSource imageSource;
  final SettingsSource settingsSource;
  final GlobalSettingsSource globalsettingsSource;
  const SettingsRepository({
    required this.settingsSource,
    required this.emoticonsSource,
    required this.imageSource,
    required this.globalsettingsSource,
  });

  Future<Either<Failure, Success>> importFromFile() async {
    try {
      final importBundle = await settingsSource.importFromFile();
      final dbVersion = await getMetadataVersion(db: importBundle.db);
      if (emoticonsSource is EmoticonsSqliteSource) {
        await (emoticonsSource as EmoticonsSqliteSource).importFromDb(
          importDb: importBundle.db,
          importStrategy: ImportStrategy.merge,
          dbVersion: dbVersion,
        );
      }
      if (imageSource is ImageSourceSQLiteAndFS) {
        await (imageSource as ImageSourceSQLiteAndFS).importFromDb(
          importReader: importBundle.importReader,
          importDb: importBundle.db,
        );
      }
      if (globalsettingsSource is GlobalSettingsSourceSQLite) {
        await (globalsettingsSource as GlobalSettingsSourceSQLite).importFromDb(
          importDb: importBundle.db,
        );
      }
      await importBundle.onImportFinish();
      return Either.right(GenericSuccess());
    } on NoImportFilePickedException catch (error, stackTrace) {
      getLogger().warning("No import file picked", error, stackTrace);
      return Either.left(FilePickingCancelledFailure());
    } on UnrecognizedImportFileException catch (error, stackTrace) {
      getLogger().warning(
        "Unrecognized file picked for import",
        error,
        stackTrace,
      );
      return Either.left(UnrecognizedFileFailure());
    } catch (error, stackTrace) {
      getLogger().severe("Error importing", error, stackTrace);
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> exportToFile({
    required ExportConfig exportConfig,
  }) async {
    try {
      final exportBundle = await settingsSource.exportToFile();
      if (exportConfig.shouldExportSettings &&
          globalsettingsSource is GlobalSettingsSourceSQLite) {
        await (globalsettingsSource as GlobalSettingsSourceSQLite).exportToDb(
          exportDb: exportBundle.db,
        );
        getLogger().config("Finished exporting settings");
      }
      if (exportConfig.shouldExportEmoticons &&
          emoticonsSource is EmoticonsSqliteSource) {
        await (emoticonsSource as EmoticonsSqliteSource).exportToDb(
          exportDb: exportBundle.db,
        );
        getLogger().config("Finished emoticons");
      }
      if (exportConfig.shouldExportEmotipics &&
          imageSource is ImageSourceSQLiteAndFS) {
        await (imageSource as ImageSourceSQLiteAndFS).exportToDb(
          exportDb: exportBundle.db,
          exportWriter: exportBundle.exportWriter,
        );
        getLogger().config("Finished emotipics");
      }
      await exportBundle.finishExport();
      getLogger().config("Finished writing");
      return Either.right(GenericSuccess());
    } on NoSaveFilePickedException catch (error, stackTrace) {
      getLogger().warning("Export file not picked", error, stackTrace);
      return Either.left(FilePickingCancelledFailure());
    } catch (error, stackTrace) {
      getLogger().severe("Error exporting", error, stackTrace);
      return Either.left(GenericFailure(error, stackTrace));
    }
  }
}
