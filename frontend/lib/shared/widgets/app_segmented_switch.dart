import 'package:flutter/material.dart';

import 'app_segmented_tabs.dart';

// A yes-or-no at the size that can stand at the end of a row: beside the name
// of a band and the hours it is set to, a control drawn for a question standing
// on its own line was wider than both of them together.
const double _height = 36;
const double _fontSize = 13;

/// Two words and a pill that slides between them.
///
/// It is [AppSegmentedTabs] with two segments and a yes-or-no where the index
/// would be: the same ground, the same pill, the same slide. Written twice they
/// would drift apart, and a switch that answers differently from the row of
/// tabs above it reads as two controls rather than one idea.
class AppSegmentedSwitch extends StatelessWidget
{
  final bool value;
  final ValueChanged<bool> onChanged;

  // What each side says. The left one is the true side, because a control that
  // reads left to right should say the thing being turned on first.
  final String trueLabel;
  final String falseLabel;

  /// See [AppSegmentedTabs.hugContent]. Set where the switch is the whole
  /// answer of a piece and has to sit in the middle of it rather than at the
  /// left end of a row it does not need.
  final bool hugContent;

  const AppSegmentedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.trueLabel = 'Sì',
    this.falseLabel = 'No',
    this.hugContent = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return AppSegmentedTabs(
      labels: [trueLabel, falseLabel],
      selectedIndex: value ? 0 : 1,
      onSelected: (index) => onChanged(index == 0),
      height: _height,
      fontSize: _fontSize,
      // It stands in a row of its own, not over what it chooses.
      padding: EdgeInsets.zero,
      hugContent: hugContent,
    );
  }
}
