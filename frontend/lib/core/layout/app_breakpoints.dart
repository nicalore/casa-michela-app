import 'package:flutter/widgets.dart';

// The three widths the app knows about. Everything that has to change shape
// when the window does — the top bar, the section rail, the page margins, the
// dialogs — asks this one question and answers it in one of three ways, so a
// page cannot end up compact in one corner and wide in another.
enum AppWindowSize
{
  // A phone, or a browser window pulled down to about half a laptop screen.
  // The destinations no longer fit along a bar and the rail no longer fits
  // beside the content: both move into the drawer.
  compact,

  // Everything the wide layout has, with less air: the bar keeps its
  // destinations but gives up the quieter half of the identity block, and the
  // page margins tighten.
  medium,

  // The layout the app was drawn for.
  expanded,
}

class AppBreakpoints
{
  // Where the bar gives up. Below this the five destinations, the wordmark and
  // the identity block cannot share a row without the words being scaled down
  // to the point of being unreadable.
  //
  // It is also the minimum width of the wide layout, on purpose: the two
  // numbers being the same is what makes the change of shape a swap rather than
  // a band of widths where the page is too narrow for one layout and too wide
  // for the other.
  static const double compactMax = 1024;

  // Below this the wide layout still works but has no room to spare.
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

  // For the places that are handed no width of their own — a dialog, which is
  // measured against the window rather than against the page under it.
  static AppWindowSize of(BuildContext context)
  {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  // Air along the sides of a page. The wide value is the one the layout was
  // drawn with; the compact one is what is left once a phone has taken its
  // share of the width for the content itself.
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

  // True where the destinations still run along the bar, which is also where
  // the rail still stands beside the content.
  bool get hasRail => this != AppWindowSize.compact;
}
