import 'package:flutter/widgets.dart';

import '../../core/layout/large_text_scale.dart';

class MobileTextScale extends StatelessWidget
{
  final Widget child;

  const MobileTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final MediaQueryData data = MediaQuery.of(context);

    return MediaQuery(data: data.copyWith(textScaler: largeTextScalerFor(data.textScaler)), child: child);
  }
}
