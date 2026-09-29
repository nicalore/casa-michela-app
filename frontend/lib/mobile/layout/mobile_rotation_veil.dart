import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('it.casamichela.app/rotation');

// iOS hides the view while rotating and asks when to show it; Android never calls.
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
  }

  @override
  void dispose()
  {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _onCall(MethodCall call) async
  {
    if (call.method == 'didRotate')
    {
      // Metrics are already updated; resolves once a frame at the new size is drawn.
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
