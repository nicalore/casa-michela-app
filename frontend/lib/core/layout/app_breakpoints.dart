import 'package:flutter/widgets.dart';

enum AppWindowSize
{
  compact,

  medium,

  expanded,
}

class AppBreakpoints
{
  // Also the minimum width of the wide layout, so the change of shape is a
  // swap rather than a band of widths where neither layout fits.
  static const double compactMax = 1024;

  static const double mediumMax = 1280;

  static AppWindowSize fromWidth(double width)
  {
    if (width < compactMax)
    {
      return AppWindowSize.compact;
    }

    if (width < mediumMax)
    {
      return AppWindowSize.medium;
    }

    return AppWindowSize.expanded;
  }

  static AppWindowSize of(BuildContext context)
  {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static double pageMargin(AppWindowSize size)
  {
    return switch (size)
    {
      AppWindowSize.compact => 16,
      AppWindowSize.medium => 28,
      AppWindowSize.expanded => 40,
    };
  }
}

extension AppWindowSizeX on AppWindowSize
{
  bool get isCompact => this == AppWindowSize.compact;

  bool get hasRail => this != AppWindowSize.compact;
}
