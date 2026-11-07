import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/italian_syllables.dart';

// Type gives way this far before a word is split at a syllable.
const double kWholeWordsFloor = 0.85;

// A text capped to some lines has none to spare for a split, so it gives way further.
const double _cappedFloor = 0.72;

// Codes, dates and addresses are never split, so they alone go on shrinking, down to this.
const double _codeFloor = 0.5;

// The last piece of a split word stays longer than this when it can.
const int _shortestTail = 2;

const double _bodySize = 14;

// Rounding must not leave a word a hair too wide.
const double _margin = 0.99;

const int _settleSteps = 4;

const String _noBreakSpace = ' ';

final RegExp _run = RegExp(r'[^ \t\r\n]+');

final RegExp _space = RegExp(r'\s');

// A word with its apostrophes and the punctuation around it; anything else counts as a code.
final RegExp _wordLike = RegExp(r"^[^\p{L}\p{N}]*[\p{L}'’]+[^\p{L}\p{N}]*$", unicode: true);

// The engine cuts a word wider than its box at any letter: this keeps a Text from getting there.
class WholeWords extends SingleChildRenderObjectWidget
{
  const WholeWords({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWholeWords();
}

class _Shrunk extends TextScaler
{
  final TextScaler base;
  final double factor;

  const _Shrunk(this.base, this.factor);

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) => other is _Shrunk && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

// Rewrites what does not fit one width at one size, and keeps the widest run it left whole.
class _WordFitter
{
  final double width;
  final TextScaler scaler;
  final TextDirection direction;
  final bool dashes;

  double widest = 0;
  bool split = false;

  _WordFitter({required this.width, required this.scaler, required this.direction, required this.dashes});

  double _measure(String text, TextStyle? style)
  {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final double measured = painter.width;

    painter.dispose();

    return measured;
  }

  String _dashed(String run, TextStyle? style)
  {
    final List<int> breaks = italianSyllableBreaks(run);
    final StringBuffer pieces = StringBuffer();
    int start = 0;

    while (_measure(run.substring(start), style) > width)
    {
      final Iterable<int> ahead = breaks.where((cut) => cut > start);

      if (ahead.isEmpty)
      {
        break;
      }

      final Iterable<int> fitting = ahead.where((cut) => _measure('${run.substring(start, cut)}-', style) <= width);
      final int end = fitting.isEmpty
          ? ahead.first
          : fitting.lastWhere((cut) => run.length - cut > _shortestTail, orElse: () => fitting.last);

      pieces.write('${run.substring(start, end)}-');
      start = end;
      split = true;
    }

    pieces.write(run.substring(start));

    return pieces.toString();
  }

  String _fitted(String run, TextStyle? style)
  {
    final double measured = _measure(run, style);

    if (measured <= width)
    {
      widest = math.max(widest, measured);

      return run;
    }

    // A pair glued against a lone last word comes apart when it does not fit.
    if (run.contains(_noBreakSpace))
    {
      return run.split(_noBreakSpace).map((word) => _fitted(word, style)).join(' ');
    }

    if (dashes && _wordLike.hasMatch(run) && italianSyllableBreaks(run).isNotEmpty)
    {
      return _dashed(run, style);
    }

    widest = math.max(widest, measured);

    return run;
  }

  InlineSpan rewrite(InlineSpan span, TextStyle? inherited)
  {
    if (span is! TextSpan)
    {
      return span;
    }

    final TextStyle? style = inherited == null ? span.style : inherited.merge(span.style);
    final String? given = span.text;
    final String? text = given?.replaceAllMapped(_run, (match) => _fitted(match[0]!, style));

    return TextSpan(
      text: text,
      children: span.children?.map((child) => rewrite(child, style)).toList(),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel ?? (text == given ? null : given),
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }
}

class _RenderWholeWords extends RenderProxyBox
{
  InlineSpan? _given;
  TextScaler? _givenScaler;
  double _longest = 0;

  InlineSpan? _shown;
  TextScaler? _shownScaler;

  // Only boxes that take their child's size: anything that aligns would move the text.
  RenderParagraph? get _paragraph
  {
    RenderObject? node = child;

    while (node is RenderProxyBox)
    {
      node = node.child;
    }

    return node is RenderParagraph ? node : null;
  }

  // A rebuild hands the widget's own text and scale back.
  void _readGiven(RenderParagraph paragraph)
  {
    if (identical(paragraph.text, _shown ?? _given) && paragraph.textScaler == (_shownScaler ?? _givenScaler))
    {
      return;
    }

    _given = paragraph.text;
    _givenScaler = paragraph.textScaler;
    _shown = null;
    _shownScaler = null;

    // The engine measures a line ending in an ellipsis as one word, and several words keep that ellipsis.
    final bool oneLine = paragraph.maxLines == 1 || (paragraph.maxLines == null && paragraph.overflow == TextOverflow.ellipsis);
    final bool severalWords = _space.hasMatch(paragraph.text.toPlainText(includeSemanticsLabels: false).trim());

    _longest = oneLine && severalWords ? 0 : paragraph.getMinIntrinsicWidth(double.infinity);
  }

  // Large system text may first give back what it added: the layout was drawn for the plain size.
  double _floorOf(RenderParagraph paragraph)
  {
    final double added = _givenScaler!.scale(_bodySize) / _bodySize;
    final double floor = math.min(kWholeWordsFloor, 1 / added);

    return paragraph.maxLines == null ? floor : math.min(floor, _cappedFloor);
  }

  // The last value says the text stayed whole, so the engine's longest word can check the size.
  (InlineSpan, double, bool) _planFor(RenderParagraph paragraph, double width)
  {
    InlineSpan text = _given!;
    double widest = _longest;

    if (widest > width && text.toPlainText(includeSemanticsLabels: false).contains(_noBreakSpace))
    {
      final _WordFitter fitter = _WordFitter(
        width: width,
        scaler: _givenScaler!,
        direction: paragraph.textDirection,
        dashes: false,
      );

      text = fitter.rewrite(text, null);
      widest = fitter.widest;
    }

    if (widest <= width)
    {
      return (text, 1, true);
    }

    final double factor = width / widest;
    final double floor = _floorOf(paragraph);

    if (factor >= floor)
    {
      return (text, factor * _margin, true);
    }

    // One line has nowhere to put a second piece: the ellipsis takes what is left.
    if (paragraph.maxLines == 1)
    {
      return (text, floor, true);
    }

    final _WordFitter fitter = _WordFitter(
      width: width * _margin,
      scaler: _Shrunk(_givenScaler!, floor),
      direction: paragraph.textDirection,
      dashes: true,
    );

    text = fitter.rewrite(text, null);

    return fitter.widest <= width
        ? (text, floor, !fitter.split)
        : (text, math.max(floor * width / fitter.widest * _margin, _codeFloor), !fitter.split);
  }

  // Letter spacing does not shrink with the type: the first estimate can leave a word a letter too wide.
  TextScaler? _settle(RenderParagraph paragraph, double factor, double width)
  {
    double settled = factor;

    for (int step = 0; ; step++)
    {
      final TextScaler? scaler = settled < 1 ? _Shrunk(_givenScaler!, settled) : null;

      paragraph.textScaler = scaler ?? _givenScaler!;

      final double longest = paragraph.getMinIntrinsicWidth(double.infinity);

      if (scaler == null || longest <= width || step == _settleSteps || settled <= _codeFloor)
      {
        return scaler;
      }

      settled = math.max(settled * width / longest * _margin, _codeFloor);
    }
  }

  void _fit(RenderParagraph paragraph)
  {
    _readGiven(paragraph);

    final double width = constraints.maxWidth;

    if (_longest <= width && _shown == null && _shownScaler == null)
    {
      return;
    }

    final (InlineSpan text, double factor, bool whole) = _planFor(paragraph, width);

    invokeLayoutCallback<BoxConstraints>((_)
    {
      paragraph.text = text;

      // The engine counts a hyphenated word whole, so a split text keeps its size.
      if (whole)
      {
        _shownScaler = _settle(paragraph, factor, width);
      }
      else
      {
        _shownScaler = _Shrunk(_givenScaler!, factor);
        paragraph.textScaler = _shownScaler!;
      }
    });

    // An equal text is not stored: what counts is what the paragraph holds now.
    _shown = identical(paragraph.text, _given) ? null : paragraph.text;
  }

  @override
  void performLayout()
  {
    final RenderParagraph? paragraph = _paragraph;

    if (paragraph != null && constraints.hasBoundedWidth && paragraph.softWrap)
    {
      _fit(paragraph);
    }

    super.performLayout();
  }
}
