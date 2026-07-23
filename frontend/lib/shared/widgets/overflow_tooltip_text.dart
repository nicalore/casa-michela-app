import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// Shows a tooltip with the full text only when the label is actually clipped.
// Overflow is measured on the real RenderParagraph after layout, not with a
// throwaway TextPainter, so it stays correct when the runtime font
// (google_fonts) finishes loading after the first frame.
class OverflowTooltipText extends StatefulWidget
{
  final String text;
  final TextStyle style;
  final int maxLines;

  const OverflowTooltipText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 2,
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

    if (oldWidget.text != widget.text || oldWidget.style != widget.style)
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

  // Deferred: the RenderParagraph exposes didExceedMaxLines only once it has
  // been laid out for the current frame.
  void _scheduleOverflowCheck()
  {
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (!mounted)
      {
        return;
      }

      final renderObject = _textKey.currentContext?.findRenderObject();

      if (renderObject is RenderParagraph)
      {
        final overflowing = renderObject.didExceedMaxLines;

        if (overflowing != _isOverflowing)
        {
          setState(() => _isOverflowing = overflowing);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final textWidget = Text(
      widget.text,
      key: _textKey,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );

    if (!_isOverflowing)
    {
      return textWidget;
    }

    return Tooltip(
      message: widget.text,
      waitDuration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: AppTheme.slate800.withValues(alpha: .98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate700, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
        ],
      ),
      child: textWidget,
    );
  }
}