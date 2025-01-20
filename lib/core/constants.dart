import 'package:emotic/core/semver.dart';

const emoticonsSourceDbName = "emoticons_source.sqlite";
const emoticonsSourceDbAsset = "assets/$emoticonsSourceDbName";
const version = SemVer(
  major: 0,
  minor: 1,
  patch: 6,
);

const sqldbName = "emoticons_sqlite";

const sqldbSettingsTableName = "settings_data";
const sqldbSettingsKeyColName = "key";
const sqldbSettingsValueColName = "value";
const sqldbSettingsKeyIsFirstTime = "is_first_time";
const sqldbSettingsKeylastUsedVersion = "last_used_version";

const sqldbEmoticonsTableName = "emoticons";
const sqldbEmoticonsId = "id";
const sqldbEmoticonsText = "text";

const sqldbTagsTableName = "tags";
const sqldbTagId = "tag_id";
const sqldbTagName = "tag_name";

const sqldbEmoticonsToTagsJoinTableName = "emoticon_to_tags";

const sqldbEmoticonsOrderingTableName = "emoticons_ordering";
const sqldbEmoticonsOrderingEmoticonId = "emoticon_id";
const sqldbEmoticonsOrderingUserOrder = "emoticon_user_order";

const sqldbTagsOrderingTableName = "tags_ordering";
const sqldbTagsOrderingTagId = "tag_id";
const sqldbTagsOrderingUserOrder = "tag_user_order";

const sqldbMetadataTableName = "emotic_metadata";
const sqldbMetadataKeyName = "key";
const sqldbMetadataValueName = "value";
const sqldbMetadataKeyVersion = "version";

const sourceLink = "https://github.com/FuturisticGoo/emotic";
