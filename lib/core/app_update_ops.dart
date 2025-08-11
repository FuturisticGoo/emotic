import 'package:emotic/core/logging.dart';
import 'package:emotic/core/entities/semver.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'init_setup.dart';

Future<void> performAppUpdateOperations({
  required SemVer? lastUsedVersion,
  required SemVer currentRunningVersion,
}) async {
  getLogger().config(
      "Performing app update operations from $lastUsedVersion to $currentRunningVersion");
  await sl<EmoticonsRepository>().getEmoticons(
    shouldLoadFromAsset: true,
  );
}
