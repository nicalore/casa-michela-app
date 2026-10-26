import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

// Below the wide window every text of the desktop app reads a tenth larger, over the user's own scale.
const double kDenseTextScale = 1.1;

class DenseTextScale extends StatelessWidget
{
  final Widget child;

  const DenseTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final MediaQueryData data = MediaQuery.of(context);

    // Always a MediaQuery, so crossing the threshold keeps the tree below it.
    return MediaQuery(
      data: AppBreakpoints.fromSize(data.size).isDense
          ? data.copyWith(textScaler: TextScaler.linear(data.textScaler.scale(1) * kDenseTextScale))
          : data,
      child: child,
    );
  }
}
