import 'dart:io';

import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/global_progress_pipe.dart';
import 'package:emotic/core/import_export_writer.dart';
import 'package:emotic/core/helper_functions.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/mutex.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emotic/core/helper_functions.dart' as hf;
import 'package:uri_content/uri_content.dart';
import 'package:uuid/v4.dart';
import 'package:path/path.dart' as p;

abstract class ImageSource {
  Future<List<EmoticImage>> getImages();
  Future<ImageRepr> getImageData({
    required Uri imageUri,
    required ImageReprConfig imageReprConfig,
  });
  Future<void> pickImagesAndSave();

  Future<void> pickDirectoryAndSaveImages();

  Future<int> saveImage({required NewOrModifyEmoticImage image});

  Future<void> deleteImage({required int imageId});

  Future<int> saveDirectory({required Uri uri});

  Future<void> deleteDirectory({required Uri uri});

  Future<List<String>> getTags();

  Future<void> saveTag({required String tag});

  Future<void> deleteTag({required String tag});

  Future<void> clearAllData();

  Future<void> modifyImageOrder({
    required EmoticImage image,
    required int newOrder,
  });

  Future<void> modifyTagOrder({
    required String tag,
    required int newOrder,
  });
}

class ImageSourceSQLiteAndFS implements ImageSource {
  final EmoticAppDataDirectory emoticAppDataDirectory;
  final GlobalProgressPipe globalProgressPipe;
  final Database db;
  ImageSourceSQLiteAndFS({
    required this.db,
    required this.emoticAppDataDirectory,
    required this.globalProgressPipe,
  }) {
    _ensureTables(db);
  }

  @override
  Future<List<EmoticImage>> getImages() {
    return _getImages(db);
  }

  @override
  Future<List<String>> getTags() {
    return _getTags(db);
  }

  @override
  Future<int> saveImage({required NewOrModifyEmoticImage image}) {
    return _saveImage(db, image: image);
  }

  @override
  Future<void> saveTag({required String tag}) {
    return _saveTag(db, tag: tag);
  }

  @override
  Future<int> saveDirectory({required Uri uri}) {
    return _saveDirectory(db, uri: uri);
  }

  @override
  Future<void> deleteImage({required int imageId}) {
    return _deleteImage(db, imageId: imageId);
  }

  @override
  Future<void> deleteTag({required String tag}) {
    return _deleteTag(db, tag: tag);
  }

  @override
  Future<void> deleteDirectory({required Uri uri}) {
    return _deleteDirectory(db, uri: uri);
  }

  @override
  Future<void> modifyImageOrder({
    required EmoticImage image,
    required int newOrder,
  }) {
    return _modifyImageOrder(
      db,
      image: image,
      newOrder: newOrder,
    );
  }

  @override
  Future<void> modifyTagOrder({
    required String tag,
    required int newOrder,
  }) {
    return _modifyTagOrder(
      db,
      tag: tag,
      newOrder: newOrder,
    );
  }

  @override
  Future<ImageRepr> getImageData({
    required Uri imageUri,
    required ImageReprConfig imageReprConfig,
  }) async {
    if (imageUri.isScheme("file")) {
      final file = File.fromUri(imageUri);
      if (await file.exists()) {
        switch (imageReprConfig) {
          case FlutterImageWidgetReprConfig(:final width, :final filterQuality):
            return FlutterImageWidgetImageRepr(
              imageUri: imageUri,
              imageWidget: Image.file(
                file,
                cacheWidth: width,
                fit: BoxFit.fitWidth,
                filterQuality: filterQuality,
              ),
            );
          case Uint8ListReprConfig():
            return Uint8ListImageRepr(
              imageUri: imageUri,
              imageBytes: await file.readAsBytes(),
            );
          case FileStreamReprConfig():
            return FileStreamImageRepr(
              imageUri: imageUri,
              imageByteStream: file.openRead().map(
                    (event) => Uint8List.fromList(event),
                  ),
            );
        }
      } else {
        throw CannotReadFromFileException();
      }
    } else if (imageUri.isScheme("content")) {
      try {
        // When using content uri, its very likely to OOM and crash when dealing
        // with many images simultaneously, so using a mutex for one at a time
        // processing. Might find a better solution later, but at least it
        // doesn't crash now B)
        final mutex = Mutex(limit: 1);
        await mutex.acquire();
        final uriContent = UriContent();
        final stream = uriContent.getContentStream(
          imageUri,
        );
        // Using WriteBuffer might seem redundant, but it reduces memory usage
        // considerably
        final buffer = WriteBuffer();
        if (imageReprConfig is! FileStreamReprConfig) {
          // If its File stream we need the stream itself, don't need it
          // as whole bytes
          await stream.forEach(buffer.putUint8List);
        }
        final data = buffer.done();

        switch (imageReprConfig) {
          case FlutterImageWidgetReprConfig(:final width, :final filterQuality):
            final imageWidget = Image.memory(
              Uint8List.view(data.buffer),
              cacheWidth: width,
              fit: BoxFit.fitWidth,
              filterQuality: filterQuality,
            );
            await mutex.release();
            return FlutterImageWidgetImageRepr(
              imageUri: imageUri,
              imageWidget: imageWidget,
            );
          case Uint8ListReprConfig():
            await mutex.release();
            return Uint8ListImageRepr(
              imageUri: imageUri,
              imageBytes: Uint8List.view(data.buffer),
            );
          case FileStreamReprConfig():
            await mutex.release();
            return FileStreamImageRepr(
              imageUri: imageUri,
              imageByteStream: stream,
            );
        }
      } catch (error, stackTrace) {
        getLogger().warning(
          "Can't read from content uri",
          error,
          stackTrace,
        );
        throw CannotReadFromContentUriException();
      }
    } else {
      getLogger().warning("Unknown scheme for image URI : $imageUri");
      throw UnknownUriSchemeException();
    }
  }

  @override
  Future<void> pickImagesAndSave() async {
    final xFileImageList = await hf.pickImages();
    if (xFileImageList == null) {
      throw NoImagePickedException();
    } else {
      final uuid = UuidV4();
      final privateImageDirPath = await emoticAppDataDirectory.imagePath;
      for (final xFileImage in xFileImageList) {
        final newImagePath = p.setExtension(
          p.join(
            privateImageDirPath,
            uuid.generate(),
          ),
          p.extension(xFileImage.name),
        );
        final fileToCopy = xFileImage.openRead();
        final fileToWrite =
            File(newImagePath).openWrite(mode: FileMode.writeOnly);
        await for (final fileBytes in fileToCopy) {
          fileToWrite.add(fileBytes);
        }
        await fileToWrite.flush();
        await fileToWrite.close();
        // await xFileImage.saveTo(newImagePath);
        final imageUri = Uri.file(newImagePath);
        await saveImage(
          image: NewOrModifyEmoticImage(
            imageUri: imageUri,
            parentDirectoryUri: null,
            tags: [],
            note: "",
          ),
        );
      }
    }
  }

  /// Saves the uri of all images and the directory uri. Does not
  /// copy the images.
  @override
  Future<void> pickDirectoryAndSaveImages() async {
    final dir = await EmoticImageDirectory.pickDirectory();
    if (dir == null) {
      throw NoDirectoryPickedException();
    }
    final imagesUriList = await dir.listImages();
    if (imagesUriList == null) {
      throw NoImageInDirectoryException();
    }

    for (final imageUri in imagesUriList) {
      await saveImage(
        image: NewOrModifyEmoticImage(
          imageUri: imageUri,
          parentDirectoryUri: dir.directoryUri,
          tags: [],
          note: "",
        ),
      );
    }
  }

  Future<RefreshImageSuccess> refreshDirectoryImages() async {
    final directoriesResult = await db.rawQuery("""
    SELECT 
      ${_SQLNames.dirId},
      ${_SQLNames.dirUri}
    FROM  
      ${_SQLNames.directoriesTableName}
    """);
    final directories = directoriesResult.map(
      (e) {
        return (
          e[_SQLNames.dirId] as int,
          Uri.parse(e[_SQLNames.dirUri] as String)
        );
      },
    );
    List<NewOrModifyEmoticImage> imagesToAdd = [];
    List<int> imagesToRemove = [];
    for (final dir in directories) {
      final savedImagesInDbResult = await db.rawQuery(
        """
      SELECT
        em.${_SQLNames.emotipicId},
        em.${_SQLNames.emotipicUri}
      FROM
        ${_SQLNames.emotipicsTableName} em
      INNER JOIN
        ${_SQLNames.emotipicsToDirectoryJoinTableName} dirjoin
      ON
        em.${_SQLNames.emotipicId}=dirjoin.${_SQLNames.emotipicId}
      WHERE
        ${_SQLNames.dirId}=?
      """,
        [dir.$1],
      );

      Map<Uri, int> savedImages = {};
      for (final row in savedImagesInDbResult) {
        savedImages[Uri.parse(row[_SQLNames.emotipicUri] as String)] =
            row[_SQLNames.emotipicId] as int;
      }

      final emoticImageDirectory = EmoticImageDirectory(dir.$2);
      final latestImagesInDir = await emoticImageDirectory.listImages();

      if (latestImagesInDir != null) {
        final newImagesUri =
            latestImagesInDir.toSet().difference(savedImages.keys.toSet());
        final invalidImagesUri =
            savedImages.keys.toSet().difference(latestImagesInDir.toSet());

        imagesToAdd.addAll(
          newImagesUri.map(
            (e) {
              return NewOrModifyEmoticImage.newImage(
                imageUri: e,
                parentDirectoryUri: dir.$2,
              );
            },
          ),
        );
        imagesToRemove.addAll(invalidImagesUri.map(
          (e) => savedImages[e]!,
        ));
      } else {
        // This means the directory doesn't exist anymore or can't be accessed.
        // Should we delete the dir from record? Or is it an overreaction?
        // For now, doing nothing
      }
    }
    for (final image in imagesToAdd) {
      await saveImage(image: image);
    }
    for (final imageId in imagesToRemove) {
      await deleteImage(imageId: imageId);
    }
    return RefreshImageSuccess(
      newImages: imagesToAdd.length,
      deletedImages: imagesToRemove.length,
    );
  }

  Future<void> exportToDb({
    required ExportWriter exportWriter,
    required Database exportDb,
  }) async {
    final allImages = await getImages();
    final allTags = await getTags();
    await _ensureTables(exportDb);
    // Save tag first to preserve order, otherwise the order will be based on
    // the tags of the emotipics which are later inserted
    for (final tag in allTags) {
      getLogger().info("Exporting tag: $tag");
      await _saveTag(exportDb, tag: tag);
    }

    int count = 1;
    final total = allImages.length;
    final uuid = UuidV4();
    for (final image in allImages) {
      getLogger().info("Exporting image: ${image.imageUri}");
      globalProgressPipe.addProgress(
        progressEvent: EmotipicsProgressUpdate(
          finishedEmotipics: count,
          totalEmotipics: total,
          message: "Copying image ${image.imageUri.pathSegments.last}",
        ),
      );
      count++;
      final imageStream = await getImageData(
        imageUri: image.imageUri,
        imageReprConfig: FileStreamReprConfig(),
      );
      if (imageStream case FileStreamImageRepr(:final imageByteStream)) {
        final relativeImageUri = await exportWriter.writeImage(
          fileStream: imageByteStream,
          fileName: "${uuid.generate()}${p.extension(image.imageUri.path)}",
        );
        await _saveImage(
          exportDb,
          image: NewOrModifyEmoticImage.copyImage(
            oldImage: image,
            imageUri: relativeImageUri,
            parentDirectoryUri: Option.none(),
          ),
        );
      } else {
        getLogger().severe(
          "WTH. We need the image as a stream, but we're"
          " getting it in a different Repr",
        );
        continue;
      }
    }
    globalProgressPipe.addProgress(
      progressEvent: EmotipicsProgressFinished(),
    );
  }

  Future<void> importFromDb({
    required ImportReader importReader,
    required Database importDb,
  }) async {
    // final dbVersion = await getMetadataVersion(db: importDb);

    // Easier this way, so that if its old version, it'll still work
    await _ensureTables(importDb);

    final allImages = await _getImages(importDb);
    final allTags = await _getTags(importDb);

    for (final tag in allTags) {
      await saveTag(tag: tag);
    }
    int count = 1;
    final total = allImages.length;
    for (final image in allImages) {
      globalProgressPipe.addProgress(
        progressEvent: EmotipicsProgressUpdate(
          finishedEmotipics: count,
          totalEmotipics: total,
          message: "Copying image ${image.imageUri.pathSegments.last}",
        ),
      );
      count++;
      final correctUri = await importReader.getAbsoluteImageUri(
        relativeImageUri: image.imageUri,
      );
      await saveImage(
        image: NewOrModifyEmoticImage.copyImage(
          oldImage: image,
          imageUri: correctUri,
          parentDirectoryUri: null,
        ),
      );
    }
  }

  @override
  Future<void> clearAllData() async {
    final images = await db.rawQuery("""
      SELECT ${_SQLNames.emotipicId}
      FROM ${_SQLNames.emotipicsTableName}
    """);
    final imageIds = images.map(
      (e) => e[_SQLNames.emotipicId] as int,
    );
    for (final imageId in imageIds) {
      await _deleteImageFromStorage(db, imageId: imageId);
    }

    // In this order cuz of foreign key references
    final allTables = [
      _SQLNames.emotipicsToDirectoryJoinTableName,
      _SQLNames.directoriesTableName,
      _SQLNames.emotipicsToTagsJoinTableName,
      _SQLNames.tagOrderingTableName,
      _SQLNames.tagsTableName,
      _SQLNames.tagsTableName,
      _SQLNames.emotipicsOrderingTableName,
      _SQLNames.emotipicsTableName
    ];
    for (final tableName in allTables) {
      await db.rawDelete("DELETE FROM $tableName");
    }
  }
}

Future<void> _ensureTables(Database db) async {
  final batch = db.batch();

  batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.emotipicsTableName}
    (
      ${_SQLNames.emotipicId} INTEGER PRIMARY KEY,
      ${_SQLNames.emotipicUri} TEXT NOT NULL,
      ${_SQLNames.emotipicNote} TEXT,
      ${_SQLNames.emotipicExcluded} INTEGER
    )
    """);

  batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.directoriesTableName}
    (
      ${_SQLNames.dirId} INTEGER PRIMARY KEY,
      ${_SQLNames.dirUri} TEXT NOT NULL
    )
    """);

  batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.tagsTableName}
    (
      ${_SQLNames.tagId} INTEGER PRIMARY KEY,
      ${_SQLNames.tagName} TEXT NOT NULL
    )
    """);

  batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.emotipicsToDirectoryJoinTableName}
    (
      ${_SQLNames.emotipicId} INTEGER NOT NULL
        REFERENCES ${_SQLNames.emotipicsTableName}(${_SQLNames.emotipicId}),
      ${_SQLNames.dirId} INTEGER NOT NULL
        REFERENCES ${_SQLNames.directoriesTableName}(${_SQLNames.dirId}),
        PRIMARY KEY (${_SQLNames.emotipicId}, ${_SQLNames.dirId})
    )
    """);

  batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.emotipicsToTagsJoinTableName}
    (
      ${_SQLNames.emotipicId} INTEGER NOT NULL
        REFERENCES ${_SQLNames.emotipicsTableName}(${_SQLNames.emotipicId}),
      ${_SQLNames.tagId} INTEGER NOT NULL
        REFERENCES ${_SQLNames.tagsTableName}(${_SQLNames.tagId}),
      PRIMARY KEY (${_SQLNames.emotipicId}, ${_SQLNames.tagId})
    )
    """);

  batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.emotipicsOrderingTableName}
    (
      ${_SQLNames.emotipicId} INTEGER NOT NULL
        REFERENCES ${_SQLNames.emotipicsTableName}(${_SQLNames.emotipicId}),
      ${_SQLNames.emotipicOrderingUserOrder} REAL NOT NULL,
      ${_SQLNames.emotipicOrderingUsageCount} INTEGER NOT NULL DEFAULT 0
    )
    """);

  batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.tagOrderingTableName}
    (
      ${_SQLNames.tagId} INTEGER NOT NULL
        REFERENCES ${_SQLNames.tagsTableName}(${_SQLNames.tagId}),
      ${_SQLNames.tagOrderingUserOrder} REAL NOT NULL,
      ${_SQLNames.tagOrderingUsageCount} INTEGER NOT NULL DEFAULT 0
    )
    """);

  batch.commit(noResult: true);
  await _prefillEmotipicsOrdering(db);
  await _prefillTagsOrdering(db);
}

Future<List<EmoticImage>> _getImages(Database db) async {
  List<EmoticImage> images = [];
  final imageSet = await db.rawQuery("""
    SELECT 
      emopi.${_SQLNames.emotipicId},
      emopi.${_SQLNames.emotipicUri},
      emopi.${_SQLNames.emotipicNote},
      emopi.${_SQLNames.emotipicExcluded}
    FROM
      ${_SQLNames.emotipicsTableName} emopi
    LEFT JOIN
      ${_SQLNames.emotipicsOrderingTableName} ord
    ON
      emopi.${_SQLNames.emotipicId}=ord.${_SQLNames.emotipicId}
    ORDER BY
      ord.${_SQLNames.tagOrderingUserOrder} ASC NULLS LAST,
      emopi.${_SQLNames.emotipicId} ASC
    """);

  for (final row in imageSet) {
    final imageId = row[_SQLNames.emotipicId] as int;
    final tagSet = await db.rawQuery(
      """
      SELECT 
        tags.${_SQLNames.tagName}
      FROM 
        ${_SQLNames.tagsTableName} AS tags
      INNER JOIN
        ${_SQLNames.emotipicsToTagsJoinTableName} AS tagjoin
      ON
        tags.${_SQLNames.tagId}=tagjoin.${_SQLNames.tagId}
      WHERE
        tagjoin.${_SQLNames.emotipicId}=?
      """,
      [imageId],
    );
    Uri? parentDirUri;
    final parentDirResult = await db.rawQuery(
      """
      SELECT  
        dirs.${_SQLNames.dirUri}
      FROM
        ${_SQLNames.directoriesTableName} dirs
      INNER JOIN
        ${_SQLNames.emotipicsToDirectoryJoinTableName} dirjoin
      ON
        dirs.${_SQLNames.dirId}=dirjoin.${_SQLNames.dirId}
      WHERE
        dirjoin.${_SQLNames.emotipicId}=?
      """,
      [imageId],
    );
    if (parentDirResult.isNotEmpty) {
      parentDirUri = Uri.tryParse(
        parentDirResult.first[_SQLNames.dirUri] as String,
      );
    }
    bool isExcluded =
        (row[_SQLNames.emotipicExcluded] as int) == 0 ? false : true;

    final image = EmoticImage(
      id: imageId,
      imageUri: Uri.parse(row[_SQLNames.emotipicUri] as String),
      parentDirectoryUri: parentDirUri,
      tags: tagSet.map(
        (row) {
          return row[_SQLNames.tagName].toString();
        },
      ).toList(),
      note: row[_SQLNames.emotipicNote] as String,
      isExcluded: isExcluded,
    );
    images.add(image);
  }
  return images;
}

Future<List<String>> _getTags(Database db) async {
  final tagResultSet = await db.rawQuery("""
SELECT 
  tg.${_SQLNames.tagName} 
FROM 
  ${_SQLNames.tagsTableName} tg
LEFT JOIN
  ${_SQLNames.tagOrderingTableName} ord
ON 
  tg.${_SQLNames.tagId}=ord.${_SQLNames.tagId}
ORDER BY
  ord.${_SQLNames.tagOrderingUserOrder} ASC NULLS LAST,
  tg.${_SQLNames.tagId} ASC
      """);
  List<String> tags = tagResultSet
      .map(
        (element) => element[_SQLNames.tagName].toString(),
      )
      .toList();
  return tags;
}

Future<int> _saveImage(
  Database db, {
  required NewOrModifyEmoticImage image,
}) async {
  int emotipicId;
  if (image.oldImage == null) {
    emotipicId = await db.rawInsert(
      """
        INSERT INTO ${_SQLNames.emotipicsTableName} 
        (
          ${_SQLNames.emotipicId}, 
          ${_SQLNames.emotipicUri}, 
          ${_SQLNames.emotipicNote}, 
          ${_SQLNames.emotipicExcluded}
        )
        VALUES 
        (?, ?, ?, ?)
        """,
      [
        null,
        image.imageUri.toString(),
        image.note,
        image.isExcluded ? 1 : 0,
      ],
    );
    // No need to link if its null, it means the image was selected by
    // itself, not through a directory
    if (image.parentDirectoryUri != null) {
      await _linkImageWithDirectory(
        db,
        emotipicId: emotipicId,
        parentDirUri: image.parentDirectoryUri!,
      );
    }
    await _appendToEmotipicsOrder(db, emotipicId: emotipicId);
  } else {
    emotipicId = image.oldImage!.id;
    // Updating notes, if there's any change
    if (image.note != image.oldImage?.note) {
      await db.rawUpdate(
        """
          UPDATE ${_SQLNames.emotipicsTableName}
          SET ${_SQLNames.emotipicNote}=?
          WHERE ${_SQLNames.emotipicId}=?
          """,
        [
          image.note,
          emotipicId,
        ],
      );
    }
  }
  // This step is the same in both cases, remove all links and relink, its
  // easier this way
  await _unlinkImageWithAllTags(db, emotipicId: emotipicId);
  for (final tag in image.tags) {
    await _linkImageWithTag(db, emotipicId: emotipicId, tag: tag);
  }
  return emotipicId;
}

Future<int> _saveTag(Database db, {required String tag}) async {
  final existing = await _getTagId(db, tag: tag);
  if (existing != null) {
    return existing;
  }
  final tagId = await db.rawInsert(
    """
    INSERT INTO ${_SQLNames.tagsTableName}
    (
      ${_SQLNames.tagId},
      ${_SQLNames.tagName}
    )
    VALUES
    (?, ?)
    """,
    [
      null,
      tag,
    ],
  );
  await _appendToTagsOrder(db, tagId: tagId);
  return tagId;
}

/// Will save a directory. Will check for duplicates, and return the
/// dirId
Future<int> _saveDirectory(Database db, {required Uri uri}) async {
  final existing = await _getIdOfDirectoryWithUri(db, uri: uri);
  if (existing != null) {
    return existing;
  }
  final dirId = await db.rawInsert(
    """
    INSERT INTO ${_SQLNames.directoriesTableName}
    (
      ${_SQLNames.dirId},
      ${_SQLNames.dirUri}
    )
    VALUES
    (?, ?)
    """,
    [
      null,
      uri.toString(),
    ],
  );
  return dirId;
}

Future<void> _deleteImage(Database db, {required int imageId}) async {
  // TODO: do as a batch perhaps?
  await _deleteImageFromStorage(db, imageId: imageId);
  await _unlinkImageWithAllTags(db, emotipicId: imageId);
  await _unlinkImageWithDirectory(db, emotipicId: imageId);
  await _deleteImageFromOrder(db, imageId: imageId);
  await db.rawDelete(
    """
    DELETE FROM ${_SQLNames.emotipicsTableName}
    WHERE ${_SQLNames.emotipicId}=?
    """,
    [imageId],
  );
}

Future<void> _deleteTag(Database db, {required String tag}) async {
  final tagId = await _getTagId(db, tag: tag);
  if (tagId != null) {
    await db.rawDelete(
      """
      DELETE FROM ${_SQLNames.emotipicsToTagsJoinTableName}
      WHERE ${_SQLNames.tagId}=?
      """,
      [tagId],
    );
    await _deleteTagFromOrder(db, tagId: tagId);
    await db.rawDelete(
      """
      DELETE FROM ${_SQLNames.tagsTableName}
      WHERE ${_SQLNames.tagId}=?
      """,
      [tagId],
    );
  }
}

Future<void> _deleteDirectory(Database db, {required Uri uri}) async {
  final dirId = await _getIdOfDirectoryWithUri(db, uri: uri);
  if (dirId != null) {
    final linkedImagesResult = await db.rawQuery(
      """
        SELECT ${_SQLNames.emotipicId}
        FROM  ${_SQLNames.emotipicsToDirectoryJoinTableName}
        WHERE ${_SQLNames.dirId}=?
        """,
      [dirId],
    );
    if (linkedImagesResult.isNotEmpty) {
      // We need to delete the images as well, so getting the ids before
      // unlinking them
      final linkedImagesId = linkedImagesResult
          .map(
            (e) => e[_SQLNames.emotipicId] as int,
          )
          .toList();
      await _unlinkDirectoryFromAllImages(
        db,
        dirId: dirId,
      );
      for (final imageId in linkedImagesId) {
        // Deleting all the images in that directory
        await _deleteImage(db, imageId: imageId);
      }
    }
    await db.rawDelete(
      """
      DELETE FROM ${_SQLNames.directoriesTableName}
      WHERE ${_SQLNames.dirId}=?
      """,
      [dirId],
    );
  }
}

Future<void> _modifyImageOrder(
  Database db, {
  required EmoticImage image,
  required int newOrder,
}) async {
  getLogger().config("Changing order of $image to $newOrder index");
  await _deleteImageFromOrder(db, imageId: image.id);

  final nMinus1AndNthValue = await getNMinus1thAndNthOrderValue(
    db: db,
    tableName: _SQLNames.emotipicsOrderingTableName,
    orderColumnName: _SQLNames.emotipicOrderingUserOrder,
    n: newOrder,
  );
  getLogger().config("N-1th and Nth order values $nMinus1AndNthValue");
  final (firstOrder, secondOrder) = getFirstAndSecondOrder(
    nMinus1thAndNthValue: nMinus1AndNthValue,
  );
  getLogger().config("firstOrder: $firstOrder and secondOrder: $secondOrder");
  final newOrderValue = getNumBetweenTwoNums(
    firstOrder: firstOrder,
    secondOrder: secondOrder,
  );

  getLogger().config("New order value between is $newOrderValue");
  // Insert the emotipic with its order
  await _insertImageWithOrder(
    db,
    imageId: image.id,
    newOrder: newOrderValue,
  );
}

Future<void> _modifyTagOrder(
  Database db, {
  required String tag,
  required int newOrder,
}) async {
  getLogger().config("Changing order of $tag to $newOrder index");
  final tagId = await _getTagId(db, tag: tag);
  if (tagId == null) {
    throw ArgumentError.value(
      tag,
      "Invalid tag",
      "Tag does not exist in the database",
    );
  }
  await _deleteTagFromOrder(db, tagId: tagId);

  final nMinus1AndNthValue = await getNMinus1thAndNthOrderValue(
    db: db,
    tableName: _SQLNames.tagOrderingTableName,
    orderColumnName: _SQLNames.tagOrderingUserOrder,
    n: newOrder,
  );
  getLogger().config("N-1th and Nth order values $nMinus1AndNthValue");
  final (firstOrder, secondOrder) = getFirstAndSecondOrder(
    nMinus1thAndNthValue: nMinus1AndNthValue,
  );
  getLogger().config("firstOrder: $firstOrder and secondOrder: $secondOrder");
  final newOrderValue = getNumBetweenTwoNums(
    firstOrder: firstOrder,
    secondOrder: secondOrder,
  );

  getLogger().config("New order value between is $newOrderValue");
  // Insert the emotipic with its order
  await _insertTagWithOrder(
    db,
    tagId: tagId,
    newOrder: newOrderValue,
  );
}

Future<void> _prefillEmotipicsOrdering(Database db) async {
  final orderCount = "order_count";
  final existing = await db.rawQuery("""
      SELECT 
        COUNT(*) AS $orderCount 
      FROM
        ${_SQLNames.emotipicsOrderingTableName}
          """);
  if (existing.single[orderCount] == 0) {
    getLogger().config("Prefilling emotipics ordering");
    await db.rawInsert("""
        INSERT INTO
          ${_SQLNames.emotipicsOrderingTableName}
          (${_SQLNames.emotipicId}, ${_SQLNames.emotipicOrderingUserOrder})
        SELECT 
          main.${_SQLNames.emotipicId}, 
          CAST(main.${_SQLNames.emotipicId} AS REAL)
        FROM
          ${_SQLNames.emotipicsTableName} main
      """);
  }
}

Future<void> _prefillTagsOrdering(Database db) async {
  final orderCount = "order_count";
  final existing = await db.rawQuery("""
      SELECT 
        COUNT(*) AS $orderCount 
      FROM
        ${_SQLNames.tagOrderingTableName}
          """);
  if (existing.single[orderCount] == 0) {
    getLogger().config("Prefilling emotipic tag ordering");
    await db.rawInsert("""
        INSERT INTO
          ${_SQLNames.tagOrderingTableName}
          (${_SQLNames.tagId}, ${_SQLNames.tagOrderingUserOrder})
        SELECT 
          main.${_SQLNames.tagId}, 
          CAST(main.${_SQLNames.tagId} AS REAL)
        FROM
          ${_SQLNames.tagsTableName} main
      """);
  }
}

Future<void> _appendToEmotipicsOrder(
  Database db, {
  required int emotipicId,
}) async {
  final currentHighestOrder = (await getCurrentMinAndMaxOrder(
    db: db,
    tableName: _SQLNames.emotipicsOrderingTableName,
    orderColumnName: _SQLNames.emotipicOrderingUserOrder,
  ))
      ?.$2;
  await _insertImageWithOrder(
    db,
    imageId: emotipicId,
    newOrder: (currentHighestOrder ?? 0.0) + 1,
  );
}

Future<void> _appendToTagsOrder(
  Database db, {
  required int tagId,
}) async {
  final currentHighestOrder = (await getCurrentMinAndMaxOrder(
    db: db,
    tableName: _SQLNames.tagOrderingTableName,
    orderColumnName: _SQLNames.tagOrderingUserOrder,
  ))
      ?.$2;
  await _insertTagWithOrder(
    db,
    tagId: tagId,
    newOrder: (currentHighestOrder ?? 0.0) + 1,
  );
}

Future<void> _insertImageWithOrder(
  Database db, {
  required int imageId,
  required double newOrder,
}) async {
  await db.rawInsert(
    """
INSERT INTO
  ${_SQLNames.emotipicsOrderingTableName}
  (${_SQLNames.emotipicId}, ${_SQLNames.emotipicOrderingUserOrder})
VALUES
  (?, ?)
    """,
    [
      imageId,
      newOrder,
    ],
  );
}

Future<void> _insertTagWithOrder(
  Database db, {
  required int tagId,
  required double newOrder,
}) async {
  await db.rawInsert(
    """
INSERT INTO
  ${_SQLNames.tagOrderingTableName}
  (${_SQLNames.tagId}, ${_SQLNames.tagOrderingUserOrder})
VALUES
  (?, ?)
    """,
    [
      tagId,
      newOrder,
    ],
  );
}

Future<void> _deleteImageFromOrder(Database db, {required int imageId}) async {
  await db.rawDelete(
    """
      DELETE FROM
        ${_SQLNames.emotipicsOrderingTableName}
      WHERE
        ${_SQLNames.emotipicId}=?
      """,
    [imageId],
  );
}

Future<void> _deleteTagFromOrder(Database db, {required int tagId}) async {
  await db.rawDelete(
    """
      DELETE FROM
        ${_SQLNames.tagOrderingTableName}
      WHERE
        ${_SQLNames.tagId}=?
            """,
    [tagId],
  );
}

/// Links the image with the given parent uri. Directory is inserted if not in
/// table already
Future<void> _linkImageWithDirectory(
  Database db, {
  required int emotipicId,
  required Uri parentDirUri,
}) async {
  final dirId = await _saveDirectory(db, uri: parentDirUri);
  await db.rawDelete(
    """
    DELETE FROM
      ${_SQLNames.emotipicsToDirectoryJoinTableName}
    WHERE
      ${_SQLNames.emotipicId}=? AND
      ${_SQLNames.dirId}=?
  """,
    [
      emotipicId,
      dirId,
    ],
  );
  await db.rawInsert(
    """
    INSERT INTO ${_SQLNames.emotipicsToDirectoryJoinTableName}
    (
      ${_SQLNames.emotipicId},
      ${_SQLNames.dirId}
    )
    VALUES
    (?, ?)
    """,
    [
      emotipicId,
      dirId,
    ],
  );
}

/// Unlink an image from the join table, only using its id
Future<void> _unlinkImageWithDirectory(
  Database db, {
  required int emotipicId,
}) async {
  await db.rawDelete(
    """
       DELETE FROM ${_SQLNames.emotipicsToDirectoryJoinTableName}
       WHERE ${_SQLNames.emotipicId} = ?
      """,
    [emotipicId],
  );
}

Future<void> _unlinkDirectoryFromAllImages(Database db,
    {required int dirId}) async {
  await db.rawDelete(
    """
       DELETE FROM ${_SQLNames.emotipicsToDirectoryJoinTableName}
       WHERE ${_SQLNames.dirId} = ?
      """,
    [dirId],
  );
}

/// Links the image with the given parent tag. Tag is inserted if not in
/// table already
Future<void> _linkImageWithTag(
  Database db, {
  required int emotipicId,
  required String tag,
}) async {
  final tagId = await _saveTag(db, tag: tag);

  await db.rawDelete(
    """
    DELETE FROM
      ${_SQLNames.emotipicsToTagsJoinTableName}
    WHERE
      ${_SQLNames.emotipicId}=? AND
      ${_SQLNames.tagId}=?
  """,
    [
      emotipicId,
      tagId,
    ],
  );

  await db.rawInsert(
    """
    INSERT INTO ${_SQLNames.emotipicsToTagsJoinTableName}
    (
      ${_SQLNames.emotipicId},
      ${_SQLNames.tagId}
    )
    VALUES
    (?, ?)
    """,
    [
      emotipicId,
      tagId,
    ],
  );
}

Future<void> _unlinkImageWithAllTags(
  Database db, {
  required int emotipicId,
}) async {
  await db.rawDelete(
    """
    DELETE FROM ${_SQLNames.emotipicsToTagsJoinTableName}
    WHERE ${_SQLNames.emotipicId} = ?
    """,
    [emotipicId],
  );
}

Future<int?> _getTagId(Database db, {required String tag}) async {
  final result = await db.rawQuery(
    """
    SELECT ${_SQLNames.tagId}
    FROM ${_SQLNames.tagsTableName}
    WHERE ${_SQLNames.tagName}=?
      """,
    [tag],
  );

  if (result.isEmpty) {
    return null;
  } else if (result.length != 1) {
    getLogger().warning("More than 1 tagId found for $tag: $result");
  }

  return result.single[_SQLNames.tagId] as int;
}

Future<int?> _getIdOfDirectoryWithUri(Database db, {required Uri uri}) async {
  final result = await db.rawQuery(
    """
    SELECT ${_SQLNames.dirId}
    FROM ${_SQLNames.directoriesTableName}
    WHERE ${_SQLNames.dirUri}=?
    """,
    [uri.toString()],
  );
  if (result.isEmpty) {
    return null;
  } else {
    return result.single[_SQLNames.dirId] as int;
  }
}

/// Will only delete those images which are in the app data directory
Future<void> _deleteImageFromStorage(Database db,
    {required int imageId}) async {
  final uriCol = "uri_col";
  final dirCol = "dir_col";
  final result = await db.rawQuery(
    """
      SELECT 
        img.${_SQLNames.emotipicUri} AS $uriCol,
        dirjoin.${_SQLNames.dirId} AS $dirCol
      FROM
        ${_SQLNames.emotipicsTableName} img
        LEFT JOIN
        ${_SQLNames.emotipicsToDirectoryJoinTableName} dirjoin
      ON 
        img.${_SQLNames.emotipicId}=dirjoin.${_SQLNames.emotipicId}
      WHERE
        img.${_SQLNames.emotipicId}=?
    """,
    [imageId],
  );
  final uri = Uri.parse(result.first[uriCol] as String);
  final parentDirId = result.first[dirCol] as int?;
  if (uri.isScheme("file") && parentDirId == null) {
    // We can only delete those image that are stored in our app data folder
    await File.fromUri(uri).delete();
  }
}

abstract final class _SQLNames {
  static const emotipicsTableName = "emotipics_images";

  /// INTEGER PRIMARY KEY
  static const emotipicId = "emotipic_id";

  /// TEXT
  static const emotipicUri = "emotipic_uri";

  /// TEXT
  static const emotipicNote = "emotipic_notes";

  /// INTEGER (BOOLEAN)
  static const emotipicExcluded = "is_excluded";

  static const directoriesTableName = "emotipics_directories";

  /// INTEGER PRIMARY KEY
  static const dirId = "dir_id";

  /// TEXT
  static const dirUri = "dir_uri";

  static const emotipicsToDirectoryJoinTableName =
      "emotipics_to_directory_join";
  // emotipicId
  // dirId

  static const tagsTableName = "emotipics_tags";

  /// INTEGER PRIMARY KEY
  static const tagId = "tag_id";
  // TEXT
  static const tagName = "tag_name";

  static const emotipicsToTagsJoinTableName = "emotipics_to_tags_join";
  // emotipicId
  // tagId

  static const emotipicsOrderingTableName = "emotipics_image_ordering";
  // emotipicId FOREIGN KEY
  /// REAL
  static const emotipicOrderingUserOrder = "user_order";
  // INTEGER
  static const emotipicOrderingUsageCount = "usage_count";

  static const tagOrderingTableName = "emotipics_tags_ordering";
  // tagId FOREIGN KEY
  /// REAL
  static const tagOrderingUserOrder = "user_order";

  /// INTEGER
  static const tagOrderingUsageCount = "usage_count";
}
