import 'package:emotic/core/entities/fancy_text_transform.dart';
import 'package:emotic/data/fancy_text_source.dart';

class FancyTextRepository {
  final FancyTextSource fancyTextSource;
  const FancyTextRepository({
    required this.fancyTextSource,
  });
  Future<List<FancyTextTransform>> getFancyTextTransforms() async {
    return fancyTextSource.getFancyTextTransforms();
  }
}
