import 'dart:typed_data';

import 'package:flutter/material.dart';

sealed class ImageReprConfig {
  const ImageReprConfig();
}

class FlutterImageWidgetReprConfig implements ImageReprConfig {
  final int? width;
  final int? height;
  final FilterQuality filterQuality;
  const FlutterImageWidgetReprConfig({
    required this.width,
    required this.height,
    required this.filterQuality,
  });
  FlutterImageWidgetReprConfig.thumbnail({
    int? preferredWidth,
    int? preferredHeight,
  })  : width = preferredWidth ?? 128,
        height = preferredWidth,
        filterQuality = FilterQuality.medium;
  FlutterImageWidgetReprConfig.full({
    int? preferredWidth,
    int? preferredHeight,
  })  : width = preferredWidth,
        height = preferredWidth,
        filterQuality = FilterQuality.high;
}

class Uint8ListReprConfig implements ImageReprConfig {}

class FileStreamReprConfig implements ImageReprConfig {}

sealed class ImageRepr {
  final Uri imageUri;
  ImageRepr({
    required this.imageUri,
  });
}

class FlutterImageWidgetImageRepr implements ImageRepr {
  final Image imageWidget;
  @override
  final Uri imageUri;
  FlutterImageWidgetImageRepr({
    required this.imageUri,
    required this.imageWidget,
  });

  Future<Image> getImageWidget() async {
    return imageWidget;
  }
}

class Uint8ListImageRepr implements ImageRepr {
  final Uint8List imageBytes;
  @override
  final Uri imageUri;
  Uint8ListImageRepr({
    required this.imageUri,
    required this.imageBytes,
  });
  Future<Uint8List> getImageBytes() async {
    return imageBytes;
  }
}

class FileStreamImageRepr implements ImageRepr {
  final Stream<Uint8List> imageByteStream;
  @override
  final Uri imageUri;
  FileStreamImageRepr({
    required this.imageUri,
    required this.imageByteStream,
  });
  Stream<Uint8List> getImageByteStream() {
    return imageByteStream;
  }
}
