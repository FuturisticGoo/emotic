import 'dart:io';
import 'dart:math';

import 'package:emotic/core/constants.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pick_or_save/pick_or_save.dart';
import 'package:file_picker/file_picker.dart';
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
      final mediaFolder = p.join(androidPath, "media", appId);
      await Directory(mediaFolder).create(recursive: true);
      return mediaFolder;
    } else {
      final dataPath = p.join(await getAppDataDir(), "media");
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

Future<List<Uri>?> pickImages() async {
  final imagesPicked = await FilePicker.platform.pickFiles(
    allowedExtensions: _imageExtensions,
    allowMultiple: true,
  );
  if (imagesPicked == null) {
    return null;
  }
}
