import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class StreamImageProvider extends ImageProvider<Uri> {
  final Uri imageUri;
  final Stream<Uint8List> imageStream;
  const StreamImageProvider({
    required this.imageUri,
    required this.imageStream,
  });
  @override
  Future<Uri> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(imageUri);
  }

  @override
  ImageStreamCompleter loadImage(Uri key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: consolidateStreamResponse(
        imageStream,
        (cumulative, total) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: cumulative,
              expectedTotalBytes: total,
            ),
          );
        },
      )
          .then<ui.ImmutableBuffer>(ui.ImmutableBuffer.fromUint8List)
          .then<ui.Codec>(decode),
      scale: 1,
      chunkEvents: chunkEvents.stream,
    );
  }
}

Future<Uint8List> consolidateStreamResponse(
  Stream<Uint8List> stream,
  void Function(int cumulative, int? total)? onBytesReceived,
) async {
  final buffer = WriteBuffer();
  await for (final bytes in stream) {
    buffer.putUint8List(bytes);
    if (onBytesReceived != null) {
      onBytesReceived(bytes.lengthInBytes, null);
    }
  }
  return buffer.done().buffer.asUint8List();
}
