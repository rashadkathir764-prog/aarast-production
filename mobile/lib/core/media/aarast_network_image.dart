import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'aarast_image_disk_cache.dart';

/// An image from the network, decoded at the size it is drawn and kept on
/// the phone (RA-MO-364). `Image.network` decoded every image at its full
/// size: a cover of up to 2200px is some 13MB in memory for a card a few
/// hundred pixels wide, and seven of them filled the image cache on
/// «استكشف», with a real risk of running out of memory on a 2GB phone.
///
/// The decoded width is the width it is laid out at times the screen's
/// pixel ratio. [keepOnDisk] is false for what is private (a chat photo, a
/// receipt): it is never written to the phone.
class AarastNetworkImage extends StatelessWidget {
  const AarastNetworkImage(
    this.url, {
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.semanticLabel,
    this.keepOnDisk = true,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;
  final String? semanticLabel;
  final bool keepOnDisk;

  @override
  Widget build(BuildContext context) {
    final given = width;
    // A given width needs no layout to be asked (and so works where the
    // parent measures its children, as a dialog does).
    if (given != null) return _image(context, given);
    return LayoutBuilder(
      builder: (context, constraints) => _image(
        context,
        constraints.hasBoundedWidth ? constraints.maxWidth : null,
      ),
    );
  }

  Widget _image(BuildContext context, double? logicalWidth) => Image(
    image: aarastNetworkImage(
      url,
      decodeWidth: aarastDecodeWidth(context, logicalWidth),
      keepOnDisk: keepOnDisk,
    ),
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    errorBuilder: errorBuilder,
    semanticLabel: semanticLabel,
  );
}

/// The pixels an image drawn [logicalWidth] wide needs on this screen; null
/// when the width is not known (it is then decoded whole).
int? aarastDecodeWidth(BuildContext context, double? logicalWidth) {
  if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
    return null;
  }
  return (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
}

/// The provider behind [AarastNetworkImage], for a place that takes an
/// [ImageProvider] (a decoration, a card drawn to a picture): decoded at
/// [decodeWidth] pixels wide when given.
ImageProvider aarastNetworkImage(
  String url, {
  required int? decodeWidth,
  bool keepOnDisk = true,
}) => ResizeImage.resizeIfNeeded(
  decodeWidth,
  null,
  AarastNetworkImageProvider(url, keepOnDisk: keepOnDisk),
);

/// An image read through [AarastImageDiskCache].
@immutable
class AarastNetworkImageProvider
    extends ImageProvider<AarastNetworkImageProvider> {
  const AarastNetworkImageProvider(
    this.url, {
    this.keepOnDisk = true,
    this.cache,
  });

  final String url;
  final bool keepOnDisk;

  /// [AarastImageDiskCache.instance] when null; tests pass their own.
  final AarastImageDiskCache? cache;

  @override
  Future<AarastNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    AarastNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: url,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
      ],
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final store = cache ?? AarastImageDiskCache.instance;
    final bytes = await store.load(url, keep: keepOnDisk);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      return await decode(buffer);
    } on Object {
      // What does not decode is not kept for the next time.
      if (keepOnDisk) await store.evict(url);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AarastNetworkImageProvider &&
      other.url == url &&
      other.keepOnDisk == keepOnDisk &&
      identical(other.cache, cache);

  @override
  int get hashCode => Object.hash(url, keepOnDisk, cache);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'AarastNetworkImageProvider')}("$url")';
}
