import 'package:flutter/material.dart';

import 'app_gradient_button.dart';

class AppAddRowButton extends StatelessWidget
{
  final String label;
  final VoidCallback onTap;

  final bool dense;

  const AppAddRowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final double height = dense ? 32 : 46;

    return Align(
      alignment: Alignment.centerRight,
      child: AppGradientButton(
        label: label,
        icon: Icons.add_rounded,
        height: height,
        fontSize: dense ? 11 : 13,
        radius: height / 2,
        horizontalPadding: dense ? 16 : 30,
        onPressed: onTap,
      ),
    );
  }
}
