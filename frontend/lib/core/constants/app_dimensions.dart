import '../layout/app_breakpoints.dart';

abstract final class AppDimensions
{
  // The floor of the wide layout, and the same number the compact layout starts
  // at: a window narrower than this does not get a squeezed desktop page, it
  // gets the compact one. It used to be 1440, which meant every browser window
  // below a full laptop screen was answered with a horizontal scrollbar.
  static const double minDashboardWidth = AppBreakpoints.compactMax;

  // Only the wide layout is held to a minimum height. The compact one is as
  // tall as the window and scrolls inside itself, the way a page on a phone is
  // expected to.
  static const double minDashboardHeight = 900.0;
}
