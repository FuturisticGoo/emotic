import 'package:equatable/equatable.dart';

abstract class FancyTextTransform extends Equatable {
  String get textTransformerName;
  const FancyTextTransform();
  String getTransformedText({required String text});
  @override
  List<Object?> get props => [textTransformerName];
}

class SimpleMappingTextTranform extends FancyTextTransform {
  @override
  final String textTransformerName;
  late final Map<String, String> transformMapping;

  SimpleMappingTextTranform({
    required this.textTransformerName,
    required String fromText,
    required String toText,
  }) {
    assert(
      fromText.runes.length == toText.runes.length,
      "For $textTransformerName, fromText "
      "length was ${fromText.runes.length} and "
      "toText length was ${toText.runes.length}",
    );
    transformMapping = Map.fromIterables(
      fromText.runes.map(String.fromCharCode),
      toText.runes.map(String.fromCharCode),
    );
  }

  @override
  String getTransformedText({required String text}) {
    final outString = StringBuffer();
    for (final char in text.runes.map(String.fromCharCode)) {
      outString.write(transformMapping[char] ?? char);
    }
    return outString.toString();
  }

  @override
  List<Object?> get props => [
        ...super.props,
        transformMapping,
      ];
}
