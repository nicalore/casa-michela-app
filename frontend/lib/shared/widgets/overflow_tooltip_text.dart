import 'package:flutter/material.dart';

// Shows a tooltip with the full text only when the label is actually clipped.
// Overflow is detected by re-measuring the text with a TextPainter at the real
// laid-out width (read from the render box after layout), instead of reading
// RenderParagraph.didExceedMaxLines: that render-object flag is unreliable on
// Flutter web, so a browser never surfaced the tooltip. A TextPainter we lay
// out ourselves is reliable everywhere. The width comes from the render box
// (not a LayoutBuilder), so the widget still works inside IntrinsicHeight,
// which queries intrinsic dimensions a LayoutBuilder cannot answer. A
// systemFonts listener re-measures once google_fonts finish loading after the
// first frame, so the result stays correct with the final font metrics.
class OverflowTooltipText extends StatefulWidget
{
  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign? textAlign;
  final InlineSpan? textSpan;

  const OverflowTooltipText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 2,
    this.textAlign,
    this.textSpan,
  });

  @override
  State<OverflowTooltipText> createState() => _OverflowTooltipTextState();
}

class _OverflowTooltipTextState extends State<OverflowTooltipText>
{
  final GlobalKey _textKey = GlobalKey();

  bool _isOverflowing = false;

  @override
  void initState()
  {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_scheduleOverflowCheck);
    _scheduleOverflowCheck();
  }

  @override
  void didUpdateWidget(covariant OverflowTooltipText oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text
        || oldWidget.style != widget.style
        || oldWidget.textSpan != widget.textSpan
        || oldWidget.maxLines != widget.maxLines)
    {
      _scheduleOverflowCheck();
    }
  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_scheduleOverflowCheck);
    super.dispose();
  }

  InlineSpan get _span =>
      widget.textSpan ?? TextSpan(text: widget.text, style: widget.style);

  // Deferred: the text must be laid out for the current frame before its width
  // is known. The overflow is then recomputed with a fresh TextPainter (rather
  // than the render object's own didExceedMaxLines) so it stays correct on web.
  void _scheduleOverflowCheck()
  {
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (!mounted)
      {
        return;
      }

      final renderObject = _textKey.currentContext?.findRenderObject();

      if (renderObject is! RenderBox || !renderObject.hasSize)
      {
        return;
      }

      final painter = TextPainter(
        text: _span,
        textDirection: Directionality.of(context),
        textAlign: widget.textAlign ?? TextAlign.start,
        maxLines: widget.maxLines,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: renderObject.size.width + 0.5);

      final overflowing = painter.didExceedMaxLines;
      painter.dispose();

      if (overflowing != _isOverflowing)
      {
        setState(() => _isOverflowing = overflowing);
      }
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget textWidget = widget.textSpan != null
      ? Text.rich(
          widget.textSpan!,
          key: _textKey,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: widget.textAlign,
          style: widget.style,
        )
      : Text(
          widget.text,
          key: _textKey,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: widget.textAlign,
          style: widget.style,
        );

    if (!_isOverflowing)
    {
      return textWidget;
    }

    return Tooltip(
      message: widget.text,
      waitDuration: const Duration(milliseconds: 600),
      child: textWidget,
    );
  }
}
