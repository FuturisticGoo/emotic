import 'package:flutter/widgets.dart';

class ImageCacheInterface {
  final Image? Function(Uri imageUri) getCachedImage;
  final void Function(Uri imageUri, Image image) setCacheImage;
  final bool Function(Uri imageUri) isImageCached;

  const ImageCacheInterface({
    required this.getCachedImage,
    required this.setCacheImage,
    required this.isImageCached,
  });
}
