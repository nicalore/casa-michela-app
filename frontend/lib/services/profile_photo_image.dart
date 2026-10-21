import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'api_service.dart';

// Photos are served only to a signed-in reader: fetched through the API client and its token.
@immutable
class ProfilePhotoImage extends ImageProvider<ProfilePhotoImage>
{
  final String path;

  // Physical pixels; a smaller photo keeps its own width.
  final int? cacheWidth;

  const ProfilePhotoImage._(this.path, this.cacheWidth);

  // Null without a photo; only API paths, so the token never reaches another host.
  static ProfilePhotoImage? of(String? path, {int? cacheWidth})
  {
    final String? trimmed = path?.trim();

    if (trimmed == null || !trimmed.startsWith('/'))
    {
      return null;
    }

    return ProfilePhotoImage._(trimmed, cacheWidth);
  }

  @override
  Future<ProfilePhotoImage> obtainKey(ImageConfiguration configuration)
  {
    return SynchronousFuture<ProfilePhotoImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(ProfilePhotoImage key, ImageDecoderCallback decode)
  {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: key.path,
    );
  }

  Future<ui.Codec> _load(ProfilePhotoImage key, ImageDecoderCallback decode) async
  {
    try
    {
      final Uint8List bytes = await ApiService().fetchProfileImage(key.path);

      return decode(await ui.ImmutableBuffer.fromUint8List(bytes), getTargetSize: _targetSize);
    }
    catch (_)
    {
      // Evicted once cached, so the next build retries instead of keeping the failure.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));

      rethrow;
    }
  }

  ui.TargetImageSize _targetSize(int width, int height)
  {
    final int? limit = cacheWidth;

    return limit == null || limit >= width
        ? ui.TargetImageSize(width: width, height: height)
        : ui.TargetImageSize(width: limit);
  }

  @override
  bool operator ==(Object other)
  {
    return other is ProfilePhotoImage && other.path == path && other.cacheWidth == cacheWidth;
  }

  @override
  int get hashCode => Object.hash(path, cacheWidth);

  @override
  String toString() => 'ProfilePhotoImage("$path", cacheWidth: $cacheWidth)';
}
