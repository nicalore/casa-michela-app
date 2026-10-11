import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import 'notice_item.dart';
import 'notice_markdown.dart';
import 'notice_strings.dart';

const double _imageMaxHeight = 320;
const double _imageRadius = 12;
const double _imageGap = 8;

typedef ImageFetcher = Future<Uint8List> Function(String key);

// Images a message shows: new ones from memory, sent ones fetched once.
class NoticeImages
{
  // Null while nothing is saved: there is nowhere to fetch from.
  final ImageFetcher? fetcher;
  final Map<String, NoticeUpload> added;
  // Shared by the details and the composer opened over them.
  final Map<String, Uint8List> _loaded;
  final Map<String, Future<Uint8List>> _fetched;

  NoticeImages({this.fetcher, Map<String, Uint8List>? loaded, Map<String, Future<Uint8List>>? fetched})
      : added = {},
        _loaded = loaded ?? {},
        _fetched = fetched ?? {};

  factory NoticeImages.ofNotice(int? noticeId)
  {
    return NoticeImages(fetcher: noticeId == null ? null : (key) => ApiService().fetchNoticeImage(noticeId, key));
  }

  // Same images, own additions: what the composer starts from.
  NoticeImages copy() => NoticeImages(fetcher: fetcher, loaded: _loaded);

  // Bytes at hand on the first frame, decoded already: nothing grows once shown.
  Uint8List? ready(String key) => added[key]?.bytes ?? _loaded[key];

  Future<Uint8List>? bytesOf(String key)
  {
    final ImageFetcher? fetch = fetcher;

    if (fetch == null)
    {
      return null;
    }

    return _fetched.putIfAbsent(key, ()
    {
      final Future<Uint8List> bytes = fetch(key);

      // Shown as soon as it lands, so it is at hand the next time; a failure is asked again.
      bytes.then<void>((data) => _loaded[key] = data, onError: (Object _) => _fetched.remove(key));

      return bytes;
    });
  }

  // Images just written, decoded by the editor already: shown without a fetch.
  void keep(Map<String, NoticeUpload> uploads)
  {
    for (final entry in uploads.entries)
    {
      _loaded[entry.key] = entry.value.bytes;
    }
  }

  // Fetched and decoded before the message opens, so it opens at its full height.
  Future<void> preload(BuildContext context, Iterable<String> keys) async
  {
    final ImageFetcher? fetch = fetcher;

    if (fetch == null)
    {
      return;
    }

    await Future.wait([
      for (final key in keys)
        if (!_loaded.containsKey(key))
          fetch(key).then((bytes) async
          {
            if (context.mounted)
            {
              await precacheImage(MemoryImage(bytes), context);
            }

            _loaded[key] = bytes;
          }),
    ]);
  }
}

class NoticeImageEmbedBuilder extends EmbedBuilder
{
  final NoticeImages images;

  const NoticeImageEmbedBuilder(this.images);

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext)
  {
    final String? imageKey = imageKeyOf(embedContext.node.value.data.toString());
    final Uint8List? ready = imageKey == null ? null : images.ready(imageKey);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _imageGap),
      child: ready != null
          ? _picture(ready)
          : _NoticeImage(bytes: imageKey == null ? null : images.bytesOf(imageKey)),
    );
  }
}

Widget _picture(Uint8List bytes)
{
  return Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _imageMaxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_imageRadius),
        child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
      ),
    ),
  );
}

class _NoticeImage extends StatelessWidget
{
  final Future<Uint8List>? bytes;

  const _NoticeImage({required this.bytes});

  Widget _unavailable()
  {
    return Container(
      height: 64,
      width: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.closedSurface,
        borderRadius: BorderRadius.circular(_imageRadius),
      ),
      child: Text(
        kImageUnavailable,
        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Future<Uint8List>? bytes = this.bytes;

    if (bytes == null)
    {
      return _unavailable();
    }

    return FutureBuilder<Uint8List>(
      future: bytes,
      builder: (context, snapshot)
      {
        if (snapshot.hasError)
        {
          return _unavailable();
        }

        final Uint8List? data = snapshot.data;

        if (data == null)
        {
          // Room kept while loading, so the text below does not jump twice.
          return const SizedBox(height: _imageMaxHeight / 2);
        }

        return _picture(data);
      },
    );
  }
}

class NoticeDividerEmbedBuilder extends EmbedBuilder
{
  const NoticeDividerEmbedBuilder();

  @override
  String get key => kDividerType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext)
  {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
    );
  }
}
