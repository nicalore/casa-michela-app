import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// White panel hosting a statistics block. SelectionArea is part of the container
// because these cards exist to be read and copied: every figure inside them must
// be selectable without each caller remembering to wrap it.
class StatCard extends StatelessWidget
{
  static const EdgeInsets _defaultPadding = EdgeInsets.all(24);

  final Widget child;
  final EdgeInsets padding;

  const StatCard({
    super.key,
    required this.child,
    this.padding = _defaultPadding,
  });

  @override
  Widget build(BuildContext context)
  {
    return SelectionArea(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      ),
    );
  }
}