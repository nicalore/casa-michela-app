import 'package:flutter/material.dart';

// Overflow is re-measured with a TextPainter at the real laid-out width:
// RenderParagraph.didExceedMaxLines is unreliable on Flutter web.
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
  // is known.
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
