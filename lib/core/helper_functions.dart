import 'dart:io';
import 'dart:math';
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/semver.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pick_or_save/pick_or_save.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uri_content/uri_content.dart';
import 'package:xdg_directories/xdg_directories.dart' as xdg;

const _imageExtensions = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"];

bool _isBetween(double a, double n, double b) {
  return (a < n) && (n < b);
}

/// Assuming that firstOrder is less than secondOrder, get another
/// double which is in between those two.
double getNumBetweenTwoNums({
  required double firstOrder,
  required double secondOrder,
}) {
  if (firstOrder >= secondOrder) {
    throw AssertionError(
        "Cannot find number between $firstOrder and $secondOrder");
  }
  final longestPrecision = max(
    firstOrder.toString().length,
    secondOrder.toString().length,
  );

  double sumAvg = (firstOrder + secondOrder) / 2;
  double numBetween = sumAvg.floorToDouble();

  for (int i = 1; i <= longestPrecision; i++) {
    if (_isBetween(firstOrder, numBetween, secondOrder)) {
      break;
    } else {
      numBetween = double.parse(
        sumAvg.toString().substring(
              0,
              (sumAvg.isNegative)
                  ? i + 1
                  : i, // If its negative, offset for the negative sign
            ),
      );
    }
  }
  if (!_isBetween(firstOrder, numBetween, secondOrder)) {
    numBetween = sumAvg;
  }
  return numBetween;
}

(double, double) getFirstAndSecondOrder({
  required (double?, double?) nMinus1thAndNthValue,
}) {
  // If n-1th value is null, then it means it is the the beginning,
  // so it should just be nth value - 1
  // If nth value is null, then it means it is at the end,
  // so it should be just n-1th value + 1
  return (
    nMinus1thAndNthValue.$1 ?? (nMinus1thAndNthValue.$2 ?? 0) - 1,
    nMinus1thAndNthValue.$2 ?? (nMinus1thAndNthValue.$1 ?? 0) + 1
  );
}

Future<Either<Failure, Success>> copyImageToClipboard({
  required EmoticImage emoticImage,
  required Uint8List imageBytes,
}) async {
  try {
    if (Platform.isAndroid || Platform.isIOS || kIsWeb) {
      await Pasteboard.writeImage(imageBytes);
      return Either.right(GenericSuccess());
    } else {
      await Pasteboard.writeFiles([File.fromUri(emoticImage.imageUri).path]);
      return Either.right(GenericSuccess());
    }
  } catch (error, stackTrace) {
    getLogger().severe("Cannot copy image to clipboard", error, stackTrace);
    return Either.left(GenericFailure(error, stackTrace));
  }
}

Future<Either<Failure, Success>> shareImage({
  required EmoticImage emoticImage,
  required Uint8List imageBytes,
  Uint8List? thumbnailBytes,
}) async {
  try {
    // Extension of the file without the dot
    final extension = p.extension(emoticImage.imageUri.path).substring(1);

    final tempImage = XFile.fromData(
      imageBytes,
      length: imageBytes.lengthInBytes,
      mimeType: "image/$extension",
    );
    XFile? thumbnailImage;
    if (thumbnailBytes != null) {
      thumbnailImage = XFile.fromData(
        thumbnailBytes,
        length: thumbnailBytes.lengthInBytes,
        mimeType: "image/$extension",
      );
    }
    final shareParams = ShareParams(
        files: [tempImage],
        previewThumbnail: thumbnailImage,
        fileNameOverrides: [
          "emotipic.$extension",
        ]);
    final result = await SharePlus.instance.share(shareParams);
    getLogger().info("Shared image with result: ${result.raw}");
    return Either.right(GenericSuccess());
  } catch (error, stackTrace) {
    getLogger().severe("Unable to share image", error, stackTrace);
    return Either.left(GenericFailure(error, stackTrace));
  }
}

Future<String> getAppId() async {
  final appSupportDir = await getApplicationSupportDirectory();
  return p.basename(appSupportDir.parent.path);
}

abstract class EmoticAppDataDirectory {
  Future<String> getAppMediaDir();

  Future<String> getAppDataDir();

  Future<String> getAppCacheDir();
}

class EmoticAppDataDirectoryImpl implements EmoticAppDataDirectory {
  @override
  Future<String> getAppMediaDir() async {
    if (Platform.isAndroid) {
      // On android, Android/media is user accessible, so using that for media
      // files
      String androidPath;
      final externalPath = await getExternalStorageDirectory();
      if (externalPath != null) {
        // We get directory .../Android/data/<appId>/files, so we just need
        // path till Android and then it should be media
        androidPath = externalPath.parent.parent.parent.path;
      } else {
        androidPath = "/storage/emulated/0/Android/";
      }
      final mediaFolder = p.join(
        androidPath,
        mediaFolderName,
        await getAppId(),
      );
      await Directory(mediaFolder).create(recursive: true);
      return mediaFolder;
    } else {
      final dataPath = p.join(await getAppDataDir(), mediaFolderName);
      await Directory(dataPath).create(recursive: true);
      return dataPath;
    }
  }

  @override
  Future<String> getAppDataDir() async {
    if (Platform.isLinux) {
      // By default in Linux, getAppSupportDirectory uses the AppId to name the
      // folder, but thats not the usual way in Linux, so I'm gonna use the app
      // name instead as the folder name
      final path = p.join(xdg.dataHome.path, appName);
      await Directory(path).create();
      return path;
    } else {
      return (await getApplicationSupportDirectory()).path;
    }
  }

  @override
  Future<String> getAppCacheDir() async {
    return (await getApplicationCacheDirectory()).path;
  }
}

extension CommonPaths on EmoticAppDataDirectory {
  Future<String> get imagePath async {
    final mediaPath = await getAppMediaDir();
    final path = p.join(mediaPath, imagesFolderName);
    await Directory(path).create(recursive: true);
    return path;
  }
}

class EmoticImageDirectory {
  final Uri directoryUri;
  const EmoticImageDirectory(this.directoryUri);

  static Future<EmoticImageDirectory?> pickDirectory() async {
    if (Platform.isAndroid) {
      final dir = await PickOrSave().directoryPicker();
      return dir == null ? null : EmoticImageDirectory(Uri.parse(dir));
    } else if (Platform.isLinux || Platform.isWindows) {
      final dir = await FilePicker.platform.getDirectoryPath();
      return dir == null ? null : EmoticImageDirectory(Uri.file(dir));
    } else {
      // idk if its supported man, bail out
      throw UnimplementedError("Apple devices are not supported");
    }
  }

  Future<List<Uri>?> listImages() async {
    if (Platform.isAndroid) {
      final fsEntities = await PickOrSave().directoryDocumentsPicker(
        params: DirectoryDocumentsPickerParams(
          directoryUri: directoryUri.toString(),
          allowedExtensions: _imageExtensions,
        ),
      );
      if (fsEntities == null) {
        return null;
      }
      List<Uri> images = [];
      for (final fsEntity in fsEntities) {
        if (fsEntity.isFile) {
          images.add(Uri.parse(fsEntity.uri));
        }
      }
      return images;
    } else if (Platform.isLinux || Platform.isWindows) {
      final fsEntities = await Directory.fromUri(directoryUri).list().toList();
      List<Uri> images = [];
      for (final fsEntity in fsEntities) {
        if ((await fsEntity.stat()).type == FileSystemEntityType.file &&
            _imageExtensions.contains(p.extension(fsEntity.path))) {
          images.add(fsEntity.uri);
        }
      }
      return images;
    } else {
      // nope
      throw UnimplementedError("Apple devices are not supported");
    }
  }
}

Future<List<XFile>?> pickImages() async {
  final imagesPicked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: _imageExtensions
        .map(
          (e) => e.substring(
            1,
          ),
        )
        .toList(), // Without the dot
    allowMultiple: true,
  );
  if (imagesPicked == null) {
    return null;
  }
  return imagesPicked.xFiles;
}

Future<Uri?> pickImportFile() async {
  final allowedExtensions = [".sqlite", ".tar.gz", ".gz"];
  if (Platform.isAndroid) {
    final filePicked = await PickOrSave().filePicker(
      params: FilePickerParams(
        enableMultipleSelection: false,
        getCachedFilePath: false,
        pickerType: PickerType.file,
        allowedExtensions: allowedExtensions,
      ),
    );
    if (filePicked == null) {
      return null;
    } else {
      return Uri.parse(filePicked.single);
    }
  } else if (Platform.isLinux || Platform.isWindows) {
    final filePicked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      withReadStream: false,
      type: FileType.custom,
      allowedExtensions: allowedExtensions
          .map(
            (e) => e.substring(1),
          )
          .toList(),
    );
    if (filePicked == null) {
      return null;
    } else {
      return Uri.file(filePicked.xFiles.single.path);
    }
  } else {
    throw UnsupportedError("Apple devices not supported");
  }
}

Stream<Uint8List> getFileStreamFromUri({required Uri uri}) {
  if (Platform.isAndroid) {
    final uriContent = UriContent();
    return uriContent.getContentStream(
      uri,
    );
  } else if (Platform.isLinux || Platform.isWindows) {
    return File.fromUri(uri).openRead().map(
          (event) => Uint8List.fromList(event),
        );
  } else {
    throw UnsupportedError("Apple devices not supported");
  }
}

// SQL common helpers

/// Get the order value at nth ordered position from beginning, and n-1th
/// order value as well, if its the first position, result will be (null, b).
/// If its the last position, result will be (a, null)
Future<(double?, double?)> getNMinus1thAndNthOrderValue({
  required Database db,
  required String tableName,
  required String orderColumnName,
  required int n,
}) async {
  if (n < 0) {
    throw ArgumentError.value(n, "n cannot be < 0");
  }
  final double? nMinus1th;
  if (n == 0) {
    nMinus1th = null;
  } else {
    final result = (await db.rawQuery(
      """
SELECT 
 $orderColumnName
FROM 
  $tableName
ORDER BY
  $orderColumnName 
LIMIT 1
OFFSET ?
    """,
      [n - 1],
    ))
        .singleOrNull;
    nMinus1th = result?[orderColumnName] as double?;
  }
  final result = (await db.rawQuery(
    """
SELECT 
 $orderColumnName
FROM 
  $tableName
ORDER BY
  $orderColumnName 
LIMIT 1
OFFSET ?
    """,
    [n],
  ))
      .singleOrNull;
  final double? nth = result?[orderColumnName] as double?;
  return (nMinus1th, nth);
}

Future<SemVer> getMetadataVersion({required Database db}) async {
  await db.execute("""
CREATE TABLE IF NOT EXISTS
  ${_SQLNames.metadataTableName}
    (
      ${_SQLNames.metadataKeyName} VARCHAR,
      ${_SQLNames.metadataValueName} VARCHAR
    )
    """);
  final versionResult = await db.rawQuery(
    """
SELECT
  ${_SQLNames.metadataValueName}
FROM
  ${_SQLNames.metadataTableName}
WHERE
  ${_SQLNames.metadataKeyName}=?
    """,
    [_SQLNames.metadataKeyVersion],
  );
  if (versionResult.length == 1) {
    final version = SemVer.fromString(
        versionResult.single[_SQLNames.metadataValueName] as String);
    getLogger().config("Source database version $version");
    return version;
  } else {
    // If it doesn't exist, assume that its pre 0.1.6 version
    getLogger().config(
      "Source database doesn't have version information,"
      " assuming pre-v0.1.6",
    );
    return SemVer.fromString("0.1.5");
  }
}

Future<(double, double)?> getCurrentMinAndMaxOrder({
  required Database db,
  required String tableName,
  required String orderColumnName,
}) async {
  final lowest = "lowest";
  final higest = "highest";
  final result = (await db.rawQuery("""
SELECT 
  MIN($orderColumnName) as $lowest,
  MAX($orderColumnName) as $higest
FROM 
  $tableName
    """)).single;
  if (result[lowest] != null) {
    return (result[lowest] as double, result[higest] as double);
  } else {
    return null;
  }
}

Future<void> commonEnsureTables({required Database db}) async {
  await db.execute("""
CREATE TABLE IF NOT EXISTS
  ${_SQLNames.metadataTableName}
    (
      ${_SQLNames.metadataKeyName} VARCHAR,
      ${_SQLNames.metadataValueName} VARCHAR
    )
    """);
  await _prefillMetadata(db: db);
}

Future<void> _prefillMetadata({required Database db}) async {
  final existingVersionRows = await db.rawQuery(
    """
SELECT 
  ${_SQLNames.metadataValueName} 
FROM
  ${_SQLNames.metadataTableName}
WHERE
  ${_SQLNames.metadataKeyName}=?
    """,
    [_SQLNames.metadataKeyVersion],
  );
  if (existingVersionRows.isNotEmpty) {
    if (existingVersionRows.length > 1) {
      getLogger()
          .warning("Existing version rows: ${existingVersionRows.length}");
    }
    final updatedRows = await db.rawDelete(
      """
UPDATE 
  ${_SQLNames.metadataTableName}
SET
  ${_SQLNames.metadataValueName}=?
WHERE
  ${_SQLNames.metadataKeyName}=? AND
  ${_SQLNames.metadataValueName}!=?
      """,
      [
        version.toString(),
        _SQLNames.metadataKeyVersion,
        version.toString(),
      ],
    );
    if (updatedRows > 0) {
      getLogger().config("Updated $updatedRows rows of version metadata");
    }
  } else {
    await db.rawInsert(
      """
INSERT INTO 
  ${_SQLNames.metadataTableName}
  (${_SQLNames.metadataKeyName}, ${_SQLNames.metadataValueName})
VALUES
  (?, ?)
      """,
      [
        _SQLNames.metadataKeyVersion,
        version.toString(),
      ],
    );
  }
}

abstract final class _SQLNames {
  static const metadataTableName = "emotic_metadata";
  static const metadataKeyName = "key";
  static const metadataValueName = "value";
  static const metadataKeyVersion = "version";
}
