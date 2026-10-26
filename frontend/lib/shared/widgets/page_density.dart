import 'package:flutter/widgets.dart';

// Set by a page whose cards, rows and buttons step down below the wide window.
class AppPageDensity extends InheritedWidget
{
  final bool dense;

  const AppPageDensity({super.key, required this.dense, required super.child});

  static bool of(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<AppPageDensity>()?.dense ?? false;
  }

  @override
  bool updateShouldNotify(AppPageDensity oldWidget) => oldWidget.dense != dense;
}
