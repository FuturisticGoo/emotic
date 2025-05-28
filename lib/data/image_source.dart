import 'dart:io';

import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/helper_functions.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/mutex.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emotic/core/helper_functions.dart' as hf;
import 'package:uri_content/uri_content.dart';
import 'package:uuid/v4.dart';
import 'package:path/path.dart' as p;

abstract class ImageSourceReadOnly {
  Future<List<EmoticImage>> getImages();
  Future<ImageRepr> getImageData({
    required Uri imageUri,
    required ImageReprConfig imageReprConfig,
  });
}

abstract class ImageSource extends ImageSourceReadOnly {
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
  final Database db;
  ImageSourceSQLiteAndFS({
    required this.db,
    required this.emoticAppDataDirectory,
  }) {
    _ensureTables();
  }

  Future<void> _ensureTables() async {
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
      ${_SQLNames.emotipicId} INTEGER 
        REFERENCES ${_SQLNames.emotipicsTableName}(${_SQLNames.emotipicId}),
      ${_SQLNames.dirId} INTEGER 
        REFERENCES ${_SQLNames.directoriesTableName}(${_SQLNames.dirId})
    )
    """);

    batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.emotipicsToTagsJoinTableName}
    (
      ${_SQLNames.emotipicId} INTEGER 
        REFERENCES ${_SQLNames.emotipicsTableName}(${_SQLNames.emotipicId}),
      ${_SQLNames.tagId} INTEGER 
        REFERENCES ${_SQLNames.tagsTableName}(${_SQLNames.tagId})
    )
    """);

    batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.emotipicsOrderingTableName}
    (
      ${_SQLNames.emotipicId} INTEGER 
        REFERENCES ${_SQLNames.emotipicsTableName}(${_SQLNames.emotipicId}),
      ${_SQLNames.emotipicOrderingUserOrder} REAL NOT NULL,
      ${_SQLNames.emotipicOrderingUsageCount} INTEGER NOT NULL DEFAULT 0
    )
    """);

    await _prefillEmotipicsOrdering();

    batch.execute("""
    CREATE TABLE IF NOT EXISTS ${_SQLNames.tagOrderingTableName}
    (
      ${_SQLNames.tagId} INTEGER 
        REFERENCES ${_SQLNames.tagsTableName}(${_SQLNames.tagId}),
      ${_SQLNames.tagOrderingUserOrder} REAL NOT NULL,
      ${_SQLNames.tagOrderingUsageCount} INTEGER NOT NULL DEFAULT 0
    )
    """);

    await _prefillTagsOrdering();

    batch.commit(noResult: true);
  }

  Future<void> _prefillEmotipicsOrdering() async {
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

  Future<void> _prefillTagsOrdering() async {
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

  Future<void> _appendToEmotipicsOrder({
    required int emotipicId,
  }) async {
    final currentHighestOrder = (await getCurrentMinAndMaxOrder(
      db: db,
      tableName: _SQLNames.emotipicsOrderingTableName,
      orderColumnName: _SQLNames.emotipicOrderingUserOrder,
    ))
        ?.$2;
    await _insertImageWithOrder(
      imageId: emotipicId,
      newOrder: (currentHighestOrder ?? 0.0) + 1,
    );
  }

  Future<void> _appendToTagsOrder({
    required int tagId,
  }) async {
    final currentHighestOrder = (await getCurrentMinAndMaxOrder(
      db: db,
      tableName: _SQLNames.tagOrderingTableName,
      orderColumnName: _SQLNames.tagOrderingUserOrder,
    ))
        ?.$2;
    await _insertTagWithOrder(
      tagId: tagId,
      newOrder: (currentHighestOrder ?? 0.0) + 1,
    );
  }

  Future<void> _insertImageWithOrder({
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

  Future<void> _insertTagWithOrder({
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

  Future<void> _deleteImageFromOrder({required int imageId}) async {
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

  Future<void> _deleteTagFromOrder({required int tagId}) async {
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

  @override
  Future<int> saveImage({
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
          emotipicId: emotipicId,
          parentDirUri: image.parentDirectoryUri!,
        );
      }
      await _appendToEmotipicsOrder(emotipicId: emotipicId);
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
    await _unlinkImageWithAllTags(emotipicId: emotipicId);
    for (final tag in image.tags) {
      await _linkImageWithTag(emotipicId: emotipicId, tag: tag);
    }
    return emotipicId;
  }

  /// Links the image with the given parent uri. Directory is inserted if not in
  /// table already
  Future<void> _linkImageWithDirectory({
    required int emotipicId,
    required Uri parentDirUri,
  }) async {
    int? dirId = await _getIdOfDirectoryWithUri(uri: parentDirUri);
    dirId ??= await saveDirectory(uri: parentDirUri);
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
  Future<void> _unlinkImageWithDirectory({
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

  Future<void> _unlinkDirectoryFromAllImages({required int dirId}) async {
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
  Future<void> _linkImageWithTag({
    required int emotipicId,
    required String tag,
  }) async {
    int? tagId = await _getTagId(tag: tag);
    tagId ??= await saveTag(tag: tag);
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

  Future<void> _unlinkImageWithAllTags({required int emotipicId}) async {
    await db.rawDelete(
      """
    DELETE FROM ${_SQLNames.emotipicsToTagsJoinTableName}
    WHERE ${_SQLNames.emotipicId} = ?
    """,
      [emotipicId],
    );
  }

  /// Will save a directory without checking for duplicates, and return the
  /// dirId
  @override
  Future<int> saveDirectory({required Uri uri}) async {
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

  @override
  Future<int> saveTag({required String tag}) async {
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
    await _appendToTagsOrder(tagId: tagId);
    return tagId;
  }

  @override
  Future<void> deleteTag({required String tag}) async {
    final tagId = await _getTagId(tag: tag);
    if (tagId != null) {
      await db.rawDelete(
        """
      DELETE FROM ${_SQLNames.emotipicsToTagsJoinTableName}
      WHERE ${_SQLNames.tagId}=?
      """,
        [tagId],
      );
      await _deleteTagFromOrder(tagId: tagId);
      await db.rawDelete(
        """
      DELETE FROM ${_SQLNames.tagsTableName}
      WHERE ${_SQLNames.tagId}=?
      """,
        [tagId],
      );
    }
  }

  Future<int?> _getTagId({required String tag}) async {
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
    } else {
      return result.single[_SQLNames.tagId] as int;
    }
  }

  Future<int?> _getIdOfDirectoryWithUri({required Uri uri}) async {
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
        final fileToWrite = File(newImagePath).openWrite();
        await fileToWrite.addStream(fileToCopy);
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

  @override
  Future<void> clearAllData() async {
    // In this order cuz of references
    final allTables = [
      _SQLNames.emotipicsToDirectoryJoinTableName,
      _SQLNames.directoriesTableName,
      _SQLNames.emotipicsToTagsJoinTableName,
      _SQLNames.tagOrderingTableName,
      _SQLNames.tagsTableName,
      _SQLNames.emotipicsOrderingTableName,
      _SQLNames.tagsTableName,
    ];
    for (final tableName in allTables) {
      await db.rawDelete("""DELETE FROM $tableName""");
    }
  }

  @override
  Future<void> deleteDirectory({required Uri uri}) async {
    final dirId = await _getIdOfDirectoryWithUri(uri: uri);
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
          dirId: dirId,
        );
        for (final imageId in linkedImagesId) {
          // Deleting all the images in that directory
          await deleteImage(imageId: imageId);
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

  @override
  Future<void> deleteImage({required int imageId}) async {
    // TODO: do as a batch perhaps?
    await _deleteImageFromStorage(imageId: imageId);
    await _unlinkImageWithAllTags(emotipicId: imageId);
    await _unlinkImageWithDirectory(emotipicId: imageId);
    await _deleteImageFromOrder(imageId: imageId);
    await db.rawDelete(
      """
    DELETE FROM ${_SQLNames.emotipicsTableName}
    WHERE ${_SQLNames.emotipicId}=?
    """,
      [imageId],
    );
  }

  /// Will only delete those images which are in the app data directory
  Future<void> _deleteImageFromStorage({required int imageId}) async {
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
        await stream.forEach(buffer.putUint8List);
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
  Future<List<EmoticImage>> getImages() async {
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

  @override
  Future<List<String>> getTags() async {
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

  @override
  Future<void> modifyImageOrder({
    required EmoticImage image,
    required int newOrder,
  }) async {
    getLogger().config("Changing order of $image to $newOrder index");
    await _deleteImageFromOrder(imageId: image.id);

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
      imageId: image.id,
      newOrder: newOrderValue,
    );
  }

  @override
  Future<void> modifyTagOrder({
    required String tag,
    required int newOrder,
  }) async {
    getLogger().config("Changing order of $tag to $newOrder index");
    final tagId = await _getTagId(tag: tag);
    if (tagId == null) {
      throw ArgumentError.value(
        tag,
        "Invalid tag",
        "Tag does not exist in the database",
      );
    }
    await _deleteTagFromOrder(tagId: tagId);

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
      tagId: tagId,
      newOrder: newOrderValue,
    );
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
