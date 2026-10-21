import 'package:flutter/widgets.dart';

// A menu shuts when the window changes size, as the system's do: its trigger moves, the menu would stay behind.
mixin CloseOnResize<T extends StatefulWidget> on State<T>
{
  Size? _window;

  bool get menuShown;

  void closeMenuForResize();

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final Size window = MediaQuery.sizeOf(context);

    if (_window != null && window != _window && menuShown)
    {
      // After the frame that reported the new size, not inside its build.
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted && menuShown)
        {
          closeMenuForResize();
        }
      });
    }

    _window = window;
  }
}
