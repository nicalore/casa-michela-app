import 'package:flutter/widgets.dart';

// Set by the dialog frame below the wide window: buttons, fields and arrows inside grow denser.
class AppDialogDensity extends InheritedWidget
{
  final bool dense;

  const AppDialogDensity({super.key, required this.dense, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppDialogDensity>()?.dense ?? false;

  @override
  bool updateShouldNotify(AppDialogDensity oldWidget) => dense != oldWidget.dense;
}

// A carousel whose arrows would fall under its card, out of sight, hands them here for the footer.
class AppDialogArrows extends ChangeNotifier
{
  (Widget, Widget)? _arrows;
  bool _disposed = false;

  (Widget, Widget)? get arrows => _arrows;

  // Late callbacks of a closing dialog land here after it is gone: ignored.
  void show((Widget, Widget)? arrows)
  {
    if (_disposed || (arrows == null && _arrows == null))
    {
      return;
    }

    _arrows = arrows;
    notifyListeners();
  }

  @override
  void dispose()
  {
    _disposed = true;
    super.dispose();
  }
}

class AppDialogArrowsScope extends InheritedWidget
{
  final AppDialogArrows arrows;

  const AppDialogArrowsScope({super.key, required this.arrows, required super.child});

  static AppDialogArrows? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppDialogArrowsScope>()?.arrows;

  @override
  bool updateShouldNotify(AppDialogArrowsScope oldWidget) => !identical(arrows, oldWidget.arrows);
}
