import 'package:equatable/equatable.dart';

class ExportConfig extends Equatable {
  final bool shouldExportSettings;
  final bool shouldExportEmoticons;
  final bool shouldExportEmotipics;
  const ExportConfig({
    required this.shouldExportSettings,
    required this.shouldExportEmoticons,
    required this.shouldExportEmotipics,
  });
  @override
  List<Object?> get props => [
        shouldExportSettings,
        shouldExportEmoticons,
        shouldExportEmotipics,
      ];
}
