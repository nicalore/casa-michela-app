import 'dart:math';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

// Mirrors IMAGE_SCHEME in backend/app/services/notice_markdown.py.
const String kNoticeImageScheme = 'image:';

// markdown_quill's own type for a horizontal rule.
const String kDividerType = 'divider';

const BlockEmbed kNoticeDivider = BlockEmbed(kDividerType, 'hr');

const Set<String> _inlineKeys = {'bold', 'italic', 'strike', 'link'};

final Random _random = Random.secure();

// Thirty-two hex digits: the server takes up to 36 letters, digits and dashes.
String newImageKey()
{
  return List.generate(32, (_) => _random.nextInt(16).toRadixString(16)).join();
}

String? imageKeyOf(String source)
{
  return source.startsWith(kNoticeImageScheme) ? source.substring(kNoticeImageScheme.length) : null;
}

Document noticeDocument(String markdown)
{
  if (markdown.trim().isEmpty)
  {
    return Document();
  }

  final converter = MarkdownToDelta(
    markdownDocument: md.Document(encodeHtml: false, inlineSyntaxes: [md.StrikethroughSyntax()]),
  );

  return Document.fromDelta(converter.convert(markdown));
}

final RegExp _listOrQuote = RegExp(r'^\s*(- |\d+\. |> )');

String noticeMarkdown(Document document)
{
  final converter = DeltaToMarkdown(
    visitLineHandleNewLine: (style, out)
    {
      out.writeln();

      if (!style.containsKey(Attribute.list.key) && !style.containsKey(Attribute.blockQuote.key))
      {
        out.writeln();
      }
    },
  );

  return _separated(converter.convert(_tidied(document.toDelta()))).trim();
}

// A line right after a list or a quote would join it: a blank line ends them.
String _separated(String markdown)
{
  final List<String> lines = markdown.split('\n');
  final List<String> separated = [];

  for (var i = 0; i < lines.length; i++)
  {
    separated.add(lines[i]);

    final String? next = i + 1 < lines.length ? lines[i + 1] : null;
    final RegExpMatch? kind = _listOrQuote.firstMatch(lines[i]);

    if (kind == null || next == null || next.isEmpty)
    {
      continue;
    }

    final String? nextKind = _listOrQuote.firstMatch(next)?.group(1);
    final bool sameKind = nextKind != null && (nextKind == '> ') == (kind.group(1) == '> ');

    if (!sameKind)
    {
      separated.add('');
    }
  }

  return separated.join('\n');
}

// Markdown ignores ** or _ next to a space: spaces leave the formatted run.
Delta _tidied(Delta delta)
{
  final tidied = Delta();

  for (final operation in delta.operations)
  {
    final Object? data = operation.data;
    final Map<String, dynamic>? attributes = operation.attributes;

    if (data is! String || attributes == null || !attributes.keys.any(_inlineKeys.contains))
    {
      tidied.push(operation);
      continue;
    }

    final String trimmed = data.trim();

    if (trimmed.isEmpty)
    {
      tidied.insert(data, _withoutInline(attributes));
      continue;
    }

    final int start = data.indexOf(trimmed);
    final String before = data.substring(0, start);
    final String after = data.substring(start + trimmed.length);

    if (before.isNotEmpty)
    {
      tidied.insert(before, _withoutInline(attributes));
    }

    tidied.insert(trimmed, attributes);

    if (after.isNotEmpty)
    {
      tidied.insert(after, _withoutInline(attributes));
    }
  }

  return tidied;
}

Map<String, dynamic>? _withoutInline(Map<String, dynamic> attributes)
{
  final kept = Map<String, dynamic>.of(attributes)..removeWhere((key, _) => _inlineKeys.contains(key));

  return kept.isEmpty ? null : kept;
}

Set<String> documentImageKeys(Document document)
{
  final keys = <String>{};

  for (final operation in document.toDelta().operations)
  {
    final Object? data = operation.data;

    if (data is Map && data[BlockEmbed.imageType] is String)
    {
      final String? key = imageKeyOf(data[BlockEmbed.imageType] as String);

      if (key != null)
      {
        keys.add(key);
      }
    }
  }

  return keys;
}
