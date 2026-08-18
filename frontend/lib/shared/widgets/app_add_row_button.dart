import 'package:flutter/material.dart';

import 'app_gradient_button.dart';

// The button that puts one more row on an editable list: another school year,
// another membership, another slot of a day.
//
// It is the primary button of the app at the size a row deserves — smaller than
// the SALVA at the foot of the window it stands in, and at the right end of the
// list, where the row it is about to add will appear.
class AppAddRowButton extends StatelessWidget
{
  final String label;
  final VoidCallback onTap;

  // Smaller, for where the button is not the only one on the card: a day has
  // three bands and each can be given another stretch of hours, and three
  // buttons at the ordinary size weigh more than the three questions they
  // stand under. Same shape, same ramp, two thirds of the room.
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
        // Half its own height either way: the button is a pill.
        radius: height / 2,
        horizontalPadding: dense ? 16 : 30,
        onPressed: onTap,
      ),
    );
  }
}
