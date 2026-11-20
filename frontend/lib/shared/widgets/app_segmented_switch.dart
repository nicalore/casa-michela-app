import 'package:flutter/material.dart';

import '../../core/language/app_language.dart';
import 'app_segmented_tabs.dart';

const double _height = 36;
const double _fontSize = 13;

class AppSegmentedSwitch extends StatelessWidget
{
  final bool value;
  final ValueChanged<bool> onChanged;

  // Null reads Sì / No in the language in force.
  final String? trueLabel;
  final String? falseLabel;

  final bool hugContent;

  const AppSegmentedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.trueLabel,
    this.falseLabel,
    this.hugContent = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return AppSegmentedTabs(
      labels: [trueLabel ?? tr('Sì', 'Yes'), falseLabel ?? tr('No', 'No')],
      selectedIndex: value ? 0 : 1,
      onSelected: (index) => onChanged(index == 0),
      height: _height,
      fontSize: _fontSize,
      padding: EdgeInsets.zero,
      hugContent: hugContent,
    );
  }
}
