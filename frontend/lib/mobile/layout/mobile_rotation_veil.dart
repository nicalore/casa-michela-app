import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme_colours.dart';
import '../shared/widgets/mobile_background.dart';

const MethodChannel _channel = MethodChannel('it.casamichela.app/rotation');

// iOS hides the view while rotating and asks when to show it; Android never calls.
// Behind it iOS paints a copy of the sea, in the colours sent from here.
class MobileRotationVeil extends StatefulWidget
{
  final Widget? child;

  const MobileRotationVeil({super.key, required this.child});

  @override
  State<MobileRotationVeil> createState() => _MobileRotationVeilState();
}

class _MobileRotationVeilState extends State<MobileRotationVeil>
{
  @override
  void initState()
  {
    super.initState();
    _channel.setMethodCallHandler(_onCall);
    ThemeColours.current.addListener(_sendBackdrop);
    ThemeColours.dark.addListener(_sendBackdrop);
    _sendBackdrop();
  }

  @override
  void dispose()
  {
    ThemeColours.current.removeListener(_sendBackdrop);
    ThemeColours.dark.removeListener(_sendBackdrop);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  static List<int> _backdrop() => [for (final colour in MobileBackground.seaColours()) colour.toARGB32()];

  // The native sea follows the theme and the mode in force, not Casa Michela's light one.
  void _sendBackdrop()
  {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS)
    {
      return;
    }

    _channel.invokeMethod<void>('setBackdrop', _backdrop()).catchError((Object _) {});
  }

  Future<Object?> _onCall(MethodCall call) async
  {
    if (call.method == 'didRotate')
    {
      // Metrics are already updated; resolves once a frame at the new size is drawn.
      await WidgetsBinding.instance.endOfFrame;
    }

    // Asked once the view is on screen, should the first sending have come before iOS listened.
    if (call.method == 'backdrop')
    {
      return _backdrop();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
