import 'package:flutter/widgets.dart';

// The shape of the window, from its width and its height.
enum AppWindowSize
{
  minimal,

  narrow,

  // Wide enough for the wide layouts, too short or too narrow for their sizes.
  compact,

  wide,
}

class AppBreakpoints
{
  static const double minimalMax = 640;

  // Also the minimum width of the wide layouts, so the change of shape is a swap.
  static const double narrowMax = 1000;

  static const double wideMinWidth = 1280;

  // About what the homes need to fit without scrolling at their full sizes.
  static const double wideMinHeight = 860;

  static AppWindowSize fromSize(Size size)
  {
    if (size.width < minimalMax)
    {
      return AppWindowSize.minimal;
    }

    if (size.width < narrowMax)
    {
      return AppWindowSize.narrow;
    }

    if (size.width < wideMinWidth || size.height < wideMinHeight)
    {
      return AppWindowSize.compact;
    }

    return AppWindowSize.wide;
  }

  static AppWindowSize of(BuildContext context)
  {
    return fromSize(MediaQuery.sizeOf(context));
  }

  // For layouts that only reflow by width: below it they stack.
  static bool isNarrowWidth(double width) => width < narrowMax;

  static double pageMargin(AppWindowSize size)
  {
    return switch (size)
    {
      AppWindowSize.minimal => 12,
      AppWindowSize.narrow => 20,
      AppWindowSize.compact => 20,
      AppWindowSize.wide => 40,
    };
  }
}

extension AppWindowSizeX on AppWindowSize
{
  // Under 1000 px: content stacks and the page scrolls as one.
  bool get isNarrow => this == AppWindowSize.minimal || this == AppWindowSize.narrow;

  bool get isMinimal => this == AppWindowSize.minimal;

  bool get hasRail => this == AppWindowSize.wide;

  // Every size but the wide one steps its bar, cards and buttons down together.
  bool get isDense => this != AppWindowSize.wide;
}
