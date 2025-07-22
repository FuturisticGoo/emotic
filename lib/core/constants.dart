import 'package:emotic/core/semver.dart';

const emoticonsSourceDbName = "emoticons_source.sqlite";
const emoticonsSourceDbAsset = "assets/$emoticonsSourceDbName";
const version = SemVer(
  major: 0,
  minor: 1,
  patch: 9,
);

const sqldbName = "emoticons_sqlite";
const exportImportDbFileName = "emoticdb.sqlite";

const appName = "Emotic";
const sourceLink = "https://github.com/FuturisticGoo/emotic";

const emoticonsTextSizeLowerLimit = 8;
const emoticonsTextSizeUpperLimit = 32;
const emotipicsColCountLowerLimit = 1;
const emotipicsColCountUpperLimit = 12;

/// Very less reasons to use this constant directly, use the helper function
const mediaFolderName = "media";
const imagesFolderName = "images";
