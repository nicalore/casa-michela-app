import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mobile_choice_tile.dart';
import 'mobile_sheet.dart';

const double _topGap = 16;
const double _tileGap = 8;

// A one-line MobileChoiceTile.
const double _tileHeight = 56;

class MobileChoice<T>
{
  final T value;
  final String label;

  // Drawn before the label, such as a face.
  final Widget? leading;

  const MobileChoice({required this.value, required this.label, this.leading});
}

// Null when dismissed; a tap on a choice picks it and closes.
Future<MobileChoice<T>?> showMobileChoiceSheet<T>({
  required BuildContext context,
  required String eyebrow,
  required String title,
  required List<MobileChoice<T>> choices,
  required T value,
})
{
  return showMobileSheet<MobileChoice<T>>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: eyebrow,
      title: title,
      content: _ChoiceList<T>(
        choices: choices,
        chosen: choices.indexWhere((choice) => choice.value == value),
        onPick: (choice) => finishMobileSheet(context, choice),
      ),
    ),
  );
}

class _ChoiceList<T> extends StatefulWidget
{
  final List<MobileChoice<T>> choices;
  final int chosen;
  final ValueChanged<MobileChoice<T>> onPick;

  const _ChoiceList({required this.choices, required this.chosen, required this.onPick});

  @override
  State<_ChoiceList<T>> createState() => _ChoiceListState<T>();
}

class _ChoiceListState<T> extends State<_ChoiceList<T>>
{
  ScrollController? _scroll;

  @override
  void dispose()
  {
    _scroll?.dispose();
    super.dispose();
  }

  // From the first frame, so a long list opens on the chosen row without a jump.
  double _offsetOfChosen(double room)
  {
    if (widget.chosen <= 0 || !room.isFinite)
    {
      return 0;
    }

    const double step = _tileHeight + _tileGap;
    final double total = _topGap + step * widget.choices.length;
    final double centred = _topGap + step * widget.chosen + _tileHeight / 2 - room / 2;

    return centred.clamp(0.0, math.max(0.0, total - room));
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        _scroll ??= ScrollController(initialScrollOffset: _offsetOfChosen(constraints.maxHeight));

        return ListView(
          controller: _scroll,
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(MobileSheet.sidePadding, _topGap, MobileSheet.sidePadding, 0),
          children: [
            for (final (i, choice) in widget.choices.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: _tileGap),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onPick(choice),
                  child: MobileChoiceTile(leading: choice.leading, label: choice.label, chosen: i == widget.chosen),
                ),
              ),
          ],
        );
      },
    );
  }
}
