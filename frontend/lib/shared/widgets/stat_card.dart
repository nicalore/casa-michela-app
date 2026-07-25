import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// White panel hosting a statistics block. Its text is intentionally not
// selectable: the statistics tab and its sub-sections must not let the figures
// be highlighted while interacting with the charts and filters.
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}