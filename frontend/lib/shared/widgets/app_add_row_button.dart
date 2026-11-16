import 'package:flutter/material.dart';

import 'app_gradient_button.dart';
import 'desktop_tour.dart';

class AppAddRowButton extends StatelessWidget
{
  final String label;
  final VoidCallback onTap;

  final bool dense;

  // Marks the button itself, not the row it is pushed across.
  final String? tour;

  // At the row's end by default.
  final Alignment alignment;

  const AppAddRowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.dense = false,
    this.tour,
    this.alignment = Alignment.centerRight,
  });

  @override
  Widget build(BuildContext context)
  {
    final double height = dense ? 32 : 46;

    return Align(
      alignment: alignment,
      child: DesktopTourTarget(
        id: tour,
        child: AppGradientButton(
          label: label,
          icon: Icons.add_rounded,
          height: height,
          fontSize: dense ? 11 : 13,
          radius: height / 2,
          horizontalPadding: dense ? 16 : 30,
          onPressed: onTap,
        ),
      ),
    );
  }
}
