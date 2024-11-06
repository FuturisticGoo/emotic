import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:emotic/core/constants.dart';

typedef GlobalCmdHandler = Future<bool> Function({
  required String? choice,
  required BackHandler backHandler,
  required QuitHandler quitHandler,
});
typedef BackHandler = void Function();
typedef QuitHandler = void Function();
typedef TagMap = Map<String, List<int>>;

Future<List<List<dynamic>>> readEmoticons({required String csvFilePath}) async {
  final emoticonsCsvString = await File(csvFilePath).readAsString();
  final emoticonDataFrame = CsvCodec(
    shouldParseNumbers: false,
    eol: "\n",
    textDelimiter: emoticonsCsvStringDelimiter,
  ).decoder.convert(emoticonsCsvString);
  return emoticonDataFrame;
}

Future<TagMap> readTags({required String jsonFilePath}) async {
  final Map<dynamic, dynamic> tagMap =
      jsonDecode(await File(jsonFilePath).readAsString());
  TagMap tagMapCasted = {};
  for (final entry in tagMap.entries) {
    tagMapCasted[entry.key] = List.from(entry.value);
  }
  return tagMapCasted;
}

Future<void> lse({required String csvFilePath}) async {
  final emoticons = await readEmoticons(csvFilePath: csvFilePath);
  for (final row in emoticons) {
    print("${row[0]}\t${row[1]}");
  }
}

Future<void> lst({required String jsonFilePath}) async {
  final tagMap = await readTags(jsonFilePath: jsonFilePath);
  print("Tag\tEmoticon id's");
  for (final entry in tagMap.entries) {
    print("${entry.key}\t${entry.value}");
  }
}

Future<void> writeTagMap({
  required TagMap tagMap,
  required String jsonFilePath,
}) async {
  await File(jsonFilePath).writeAsString(jsonEncode(tagMap));
  print("Finished writing tags to json!");
}

Future<void> writeEmoticons({
  required List<String> newEmoticons,
  required String csvFilePath,
}) async {
  final existing = await readEmoticons(csvFilePath: csvFilePath);
  int currentLastId = int.parse(existing.last[0]);
  final existingEmoticonSet = existing.sublist(1).map((row) => row[1]).toSet();
  final newEmoticonSet = newEmoticons.toSet();

  final duplicates = newEmoticonSet.intersection(existingEmoticonSet);
  if (duplicates.isNotEmpty) {
    print("The following emoticons alredy exists  /ᐠ｡ꞈ｡ᐟ\");
    for (final emoticon in duplicates) {
        print("- $emoticon");
    }
    print("Skipping these emoticons...");
  }

  // I think its easier to just write it directly instead of using csv write
  final csvStringToAdd = StringBuffer();
  for (final emoticon in newEmoticonSet.difference(existingEmoticonSet)) {
    csvStringToAdd.write("${++currentLastId},\u001F$emoticon\u001F\n");
  }
  await File(csvFilePath)
      .writeAsString(csvStringToAdd.toString(), mode: FileMode.append);
  print("Finished writing emoticons to csv!");
}

Future<void> addNewEmoticons({
  required String csvFilePath,
  required GlobalCmdHandler globalCmdHandler,
  required QuitHandler quitHandler,
}) async {
  List<String> newEmoticons = [];
  print("Type out each emoticon line by line, 'b' to stop");
  bool shouldContinue = true;
  while (shouldContinue) {
    final readString = stdin.readLineSync();
    final handled = await globalCmdHandler(
      choice: readString,
      backHandler: () {
        shouldContinue = false;
      },
      quitHandler: () {
        shouldContinue = false;
        quitHandler();
      },
    );
    if (!handled && readString != null) {
      newEmoticons.add(readString);
    }
  }
  await writeEmoticons(
    newEmoticons: newEmoticons,
    csvFilePath: csvFilePath,
  );
}

Future<void> addNewTag({
  required String jsonFilePath,
  required GlobalCmdHandler globalCmdHandler,
  required QuitHandler quitHandler,
}) async {
  TagMap tagMap = await readTags(jsonFilePath: jsonFilePath);
  List<String> newTags = [];
  print("Type out each tag line by line, 'b' to stop");
  bool shouldContinue = true;
  while (shouldContinue) {
    final readString = stdin.readLineSync();
    final handled = await globalCmdHandler(
      choice: readString,
      backHandler: () {
        shouldContinue = false;
      },
      quitHandler: () {
        shouldContinue = false;
        quitHandler();
      },
    );
    if (!handled && readString != null) {
      newTags.add(readString);
    }

    for (final tag in newTags) {
      if (!tagMap.containsKey(tag)) {
        tagMap[tag] = [];
      }
    }
  }
  await writeTagMap(tagMap: tagMap, jsonFilePath: jsonFilePath);
}

Future<bool> checkEmoticonIdsValid({
  required Set<int> idsToCheck,
  required String csvFilePath,
}) async {
  final emoticons = await readEmoticons(csvFilePath: csvFilePath);
  Set<int> ids = {};
  for (final row in emoticons.sublist(1)) {
    ids.add(int.parse(row[0]));
  }
  return ids.containsAll(idsToCheck);
}

Future<void> modifyEmoticonIdsOfTag({
  required String jsonFilePath,
  required String csvFilePath,
  required GlobalCmdHandler globalCmdHandler,
  required QuitHandler quitHandler,
  required bool isRemoveMode,
}) async {
  TagMap tagMap = await readTags(jsonFilePath: jsonFilePath);
  for (final tag in tagMap.keys.indexed) {
    stdout.write("${tag.$1})${tag.$2}\t");
  }
  print("");
  bool shouldContinue = true;
  bool shouldGoBack = false;
  String? chosenTag;
  while (shouldContinue) {
    stdout.write("Choose tag: ");
    final readString = stdin.readLineSync();
    final handled = await globalCmdHandler(
      choice: readString,
      backHandler: () {
        shouldContinue = false;
        shouldGoBack = true;
      },
      quitHandler: () {
        shouldContinue = false;
        shouldGoBack = true;
        quitHandler();
      },
    );
    if (!handled) {
      int? tagIndex = int.tryParse(readString ?? "");
      if (tagIndex == null || tagMap.keys.elementAtOrNull(tagIndex) == null) {
        print("Type the correct tag index");
      } else {
        chosenTag = tagMap.keys.elementAt(tagIndex);
        shouldContinue = false;
      }
    }
  }
  if (shouldGoBack) {
    return;
  }
  shouldContinue = true;
  shouldGoBack = false;
  Set<int> emoticonIds = {};
  while (shouldContinue) {
    stdout.write(
      "Type emoticon ids to ${isRemoveMode ? 'remove' : 'add'}, seperated by space: ",
    );
    final readString = stdin.readLineSync();
    final handled = await globalCmdHandler(
      choice: readString,
      backHandler: () {
        shouldContinue = false;
        shouldGoBack = true;
      },
      quitHandler: () {
        shouldContinue = false;
        shouldGoBack = true;
        quitHandler();
      },
    );
    if (!handled && readString != null) {
      try {
        Set<int> ids = readString
            .split(" ")
            .map(
              (e) => int.parse(e.trim()),
            )
            .toSet();
        if (await checkEmoticonIdsValid(
          idsToCheck: ids,
          csvFilePath: csvFilePath,
        )) {
          emoticonIds = ids;
          shouldContinue = false;
        } else {
          print("Invalid emoticon id entered, try again.");
        }
      } catch (error) {
        print("Type correctly. $error");
      }
    } else if (readString == null) {
      print("Type correctly.");
    }
  }
  if (shouldGoBack) {
    return;
  } else {
    TagMap newTagMap = tagMap;
    if (isRemoveMode) {
      newTagMap[chosenTag!] =
          newTagMap[chosenTag]!.toSet().difference(emoticonIds).toList();
    } else {
      newTagMap[chosenTag!] =
          newTagMap[chosenTag]!.toSet().union(emoticonIds).toList();
    }
    await writeTagMap(tagMap: tagMap, jsonFilePath: jsonFilePath);
  }
}

Future<void> removeTag({
  required String jsonFilePath,
  required GlobalCmdHandler globalCmdHandler,
  required QuitHandler quitHandler,
}) async {
  TagMap tagMap = await readTags(jsonFilePath: jsonFilePath);
  for (final tag in tagMap.keys.indexed) {
    stdout.write("${tag.$1})${tag.$2}\t");
  }
  print("");
  bool shouldContinue = true;
  bool shouldGoBack = false;
  List<String> chosenTags = [];
  while (shouldContinue) {
    stdout.write("Choose tag to remove, seperated by space: ");
    final readString = stdin.readLineSync();
    final handled = await globalCmdHandler(
      choice: readString,
      backHandler: () {
        shouldContinue = false;
        shouldGoBack = true;
      },
      quitHandler: () {
        shouldContinue = false;
        shouldGoBack = true;
        quitHandler();
      },
    );
    if (!handled && readString != null) {
      List<int> tagIndices = [];
      try {
        tagIndices = readString.split(" ").map(int.parse).toList();
        chosenTags = tagIndices.map((i) {
          return tagMap.keys.indexed.elementAt(i).$2;
        }).toList();
        shouldContinue = false;
      } catch (error, stacktrace) {
        print("Type the correct tag index, $error, $stacktrace");
      }
    } else if (readString == null) {
      print("Type the correct tag index");
    }
  }
  if (shouldGoBack) {
    return;
  }
  tagMap.removeWhere((key, _) => chosenTags.contains(key));
  await writeTagMap(tagMap: tagMap, jsonFilePath: jsonFilePath);
}

void printHelp() {
  print("""*** Script to add and modify emoticons and tags ***
Global commands (these commands will work everywhere)
help: show this menu
lse: show all emoticons with their id's
lst: show all tags and the emoticon id's which are under it
b: go back a menu
quit: exit this program

Menu
1) Add new emoticons
2) Add new tag
3) Add emoticon id's to tag
4) Remove emoticon id's from tag
5) Remove tag""");
}

Future<bool> handleGlobalCommands({
  required String? choice,
  required String csvFilePath,
  required String jsonFilePath,
  required void Function() quitHandler,
  required void Function() backHandler,
}) async {
  bool handled = true;
  switch (choice) {
    case "help":
      printHelp();
    case "lse":
      await lse(csvFilePath: csvFilePath);
      break;
    case "lst":
      await lst(jsonFilePath: jsonFilePath);
      break;
    case "b":
      backHandler();
      break;
    case "quit":
      print("Good bi den ( ^_^)／");
      quitHandler();
      break;
    default:
      handled = false;
  }
  return handled;
}

void main() async {
  const csvFilePath = "assets/emoticons.csv";
  const jsonFilePath = "assets/tag_to_emoticon_map.json";
  printHelp();
  bool shouldContinue = true;
  Future<bool> globalCmdHandlerApplied({
    required String? choice,
    required BackHandler backHandler,
    required QuitHandler quitHandler,
  }) async {
    return await handleGlobalCommands(
      choice: choice,
      csvFilePath: csvFilePath,
      jsonFilePath: jsonFilePath,
      backHandler: backHandler,
      quitHandler: quitHandler,
    );
  }

  while (shouldContinue) {
    stdout.write("Enter choice: ");
    final choice = stdin.readLineSync();
    final handled = await globalCmdHandlerApplied(
      choice: choice,
      backHandler: () {
        print("There's no going back now ╭( ๐_๐)╮");
      },
      quitHandler: () {
        shouldContinue = false;
      },
    );
    switch (choice) {
      case "1":
        await addNewEmoticons(
          csvFilePath: csvFilePath,
          globalCmdHandler: globalCmdHandlerApplied,
          quitHandler: () {
            shouldContinue = false;
          },
        );
        break;
      case "2":
        await addNewTag(
          jsonFilePath: jsonFilePath,
          globalCmdHandler: globalCmdHandlerApplied,
          quitHandler: () {
            shouldContinue = false;
          },
        );
        break;
      case "3":
        await modifyEmoticonIdsOfTag(
          jsonFilePath: jsonFilePath,
          csvFilePath: csvFilePath,
          globalCmdHandler: globalCmdHandlerApplied,
          quitHandler: () {
            shouldContinue = false;
          },
          isRemoveMode: false,
        );
        break;
      case "4":
        await modifyEmoticonIdsOfTag(
          jsonFilePath: jsonFilePath,
          csvFilePath: csvFilePath,
          globalCmdHandler: globalCmdHandlerApplied,
          quitHandler: () {
            shouldContinue = false;
          },
          isRemoveMode: true,
        );
        break;
      case "5":
        await removeTag(
          jsonFilePath: jsonFilePath,
          globalCmdHandler: globalCmdHandlerApplied,
          quitHandler: () {
            shouldContinue = false;
          },
        );
      default:
        if (!handled) {
          print("Type correctly you dingus ಠ_ಠ");
        }
    }
    print("");
  }
}
