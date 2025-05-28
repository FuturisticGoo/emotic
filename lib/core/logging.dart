import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

const _loggerName = "EmoticLogger";
Future<void> initLogger() async {
  Logger.root.level = Level.ALL;
  final logger = Logger(_loggerName);
  logger.onRecord.listen(
    (record) {
      final outputString = StringBuffer();
      switch (record.level) {
        case Level.SHOUT:
          outputString.write("\x1B[41m"); // Red background
        case Level.SEVERE:
          outputString.write("\x1B[31m"); // Red foreground
        case Level.WARNING:
          outputString.write("\x1B[33m"); // Yellow foreground
        case Level.INFO:
          outputString.write("\x1B[35m"); // Magenta background
        case Level.CONFIG:
          outputString.write("\x1B[36m"); // Cyan foreground
        case Level.FINE:
          outputString.write("\x1B[1;92m"); // Green bold intense foreground
        case Level.FINER:
        case Level.FINEST:
          outputString.write("\x1B[0;32m"); // Green foreground
      }

      outputString
          .write('${record.level.name}: ${record.time}: ${record.message}');
      final errorObj = record.error;
      if (errorObj != null) {
        outputString.write(
          "\n$errorObj",
        );
      }
      if (record.stackTrace != null) {
        outputString.write("\nStacktrace: ${record.stackTrace}");
      }
      outputString.write("\x1B[0m");
      debugPrint(outputString.toString());
    },
  );
}

Logger getLogger() {
  return Logger(_loggerName);
}

Future<void> disposeLogger() async {
  getLogger().clearListeners();
}
