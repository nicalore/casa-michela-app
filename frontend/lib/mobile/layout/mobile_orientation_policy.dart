import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_breakpoints.dart';

// Read from the view, not in main(): Android can report a zero size before the first frame.
class MobileOrientationPolicy extends StatefulWidget
{
  final Widget child;

  const MobileOrientationPolicy({super.key, required this.child});

  @override
  State<MobileOrientationPolicy> createState() => _MobileOrientationPolicyState();
}

class _MobileOrientationPolicyState extends State<MobileOrientationPolicy> with WidgetsBindingObserver
{
  MobileFormFactor? _applied;

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _apply();
  }

  @override
  void didChangeMetrics() => _apply();

  @override
  void dispose()
  {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _apply()
  {
    final view = View.of(context);

    if (view.physicalSize.isEmpty)
    {
      return;
    }

    final factor = MobileBreakpoints.fromShortestSide(
      view.physicalSize.shortestSide / view.devicePixelRatio,
    );

    if (factor == _applied)
    {
      return;
    }

    _applied = factor;

    // An empty list defers to the OS: free rotation.
    SystemChrome.setPreferredOrientations(
      factor.isTablet ? const [] : const [DeviceOrientation.portraitUp],
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
