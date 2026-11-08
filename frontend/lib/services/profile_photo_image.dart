import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'api_service.dart';
import 'profile_photo_shrink_stub.dart' if (dart.library.js_interop) 'profile_photo_shrink_web.dart';

// Photos are served only to a signed-in reader: fetched through the API client and its token.
@immutable
class ProfilePhotoImage extends ImageProvider<ProfilePhotoImage>
{
  final String path;

  // Physical pixels the shorter side reaches, so wide photos still cover a circle; smaller ones keep their size.
  final int? cacheWidth;

  // The web shrinks faces to the drawn pixels: nearest keeps them sharp at fractional positions.
  static const FilterQuality filterQuality = kIsWeb ? FilterQuality.none : FilterQuality.medium;

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
    // The web engine shrinks decodes without filtering and faces come out grainy: the browser shrinks them.
    if (kIsWeb)
    {
      return OneFrameImageStreamCompleter(_evictOnFailure(key, () => _loadShrunk(key)));
    }

    return MultiFrameImageStreamCompleter(
      codec: _evictOnFailure(key, () => _load(key, decode)),
      scale: 1,
      debugLabel: key.path,
    );
  }

  Future<ui.Codec> _load(ProfilePhotoImage key, ImageDecoderCallback decode) async
  {
    final Uint8List bytes = await ApiService().fetchProfileImage(key.path);

    return decode(await ui.ImmutableBuffer.fromUint8List(bytes), getTargetSize: _targetSize);
  }

  Future<ImageInfo> _loadShrunk(ProfilePhotoImage key) async
  {
    final Uint8List bytes = await ApiService().fetchProfileImage(key.path);

    return ImageInfo(image: await shrinkProfilePhotoImpl(bytes, key.cacheWidth), debugLabel: key.path);
  }

  Future<T> _evictOnFailure<T>(ProfilePhotoImage key, Future<T> Function() load) async
  {
    try
    {
      return await load();
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

    if (limit == null || limit >= math.min(width, height))
    {
      return ui.TargetImageSize(width: width, height: height);
    }

    return width <= height ? ui.TargetImageSize(width: limit) : ui.TargetImageSize(height: limit);
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
