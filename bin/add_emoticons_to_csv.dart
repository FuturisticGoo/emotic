import 'dart:io';

import 'package:csv/csv.dart';
import 'package:emotic/core/constants.dart';

void main() async {
  const csvFilePath = "assets/emoticons.csv";
  print("""*** Script to add new emoticons to the csv file ***
Type/Paste each emoticon line by line. When its over, type "quit"
Begin: """);
  List<String> newEmoticons = [];
  while (true) {
    final readString = stdin.readLineSync();
    if (readString == "quit") {
      break;
    }
    if (readString != null) {
      newEmoticons.add(readString);
    }
  }
  final emoticonsCsvString = await File(csvFilePath).readAsString();
  final emoticonDataFrame = CsvCodec(
    shouldParseNumbers: false,
    eol: "\n",
    textDelimiter: emoticonsCsvStringDelimiter,
  ).decoder.convert(emoticonsCsvString);
  int currentLastId = int.parse(emoticonDataFrame.last[0]);
  // I think its easier to just write it directly instead of using csv write
  final csvStringToAdd = StringBuffer();
  for (final emoticon in newEmoticons) {
    csvStringToAdd.write("${++currentLastId},\u001F$emoticon\u001F\n");
  }
  await File(csvFilePath)
      .writeAsString(csvStringToAdd.toString(), mode: FileMode.append);
  print("Written to csv file");
}
