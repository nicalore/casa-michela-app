import 'package:flutter/material.dart';

// Text that keeps its own look and underlines under the pointer: it leads somewhere.
class AppTextLink extends StatefulWidget
{
  final String text;
  final TextStyle style;
  final VoidCallback onTap;

  // Draws the text in the style given, when a plain Text is not enough (lines, ellipsis, tooltip).
  final Widget Function(TextStyle style)? write;

  const AppTextLink({super.key, required this.text, required this.style, required this.onTap, this.write});

  @override
  State<AppTextLink> createState() => _AppTextLinkState();
}

class _AppTextLinkState extends State<AppTextLink>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final TextStyle style = widget.style.copyWith(
      decoration: _hover ? TextDecoration.underline : null,
      decorationColor: widget.style.color,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.write?.call(style) ?? Text(widget.text, style: style),
      ),
    );
  }
}
