import 'package:flutter/material.dart';

class CardScrollArea extends StatelessWidget
{
  static const double maxHeight = 420;

  final Widget child;

  final EdgeInsets padding;

  const CardScrollArea({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context)
  {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: padding,
        child: child,
      ),
    );
  }
}
