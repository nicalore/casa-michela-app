import 'package:flutter/widgets.dart';

// Cells in rows of [columns] equal widths; a short last row keeps that width.
class EqualColumns extends StatelessWidget
{
  final int columns;
  final double gap;
  final List<Widget> children;

  const EqualColumns({super.key, required this.columns, required this.gap, required this.children});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < children.length; start += columns) ...[
          if (start > 0) SizedBox(height: gap),
          Row(
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) SizedBox(width: gap),
                Expanded(child: start + column < children.length ? children[start + column] : const SizedBox.shrink()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
