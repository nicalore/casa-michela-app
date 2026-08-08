import 'package:flutter/material.dart';

// The buttons at the foot of a dialog.
//
// Two of them where the window is a question and they are its two answers: back
// out on the left, go through with it on the right, in equal halves, because
// neither is a footnote to the other.
//
// One of them everywhere else. A window that is not a question has one thing to
// do at its foot and one way out at its head, and the way out is the cross:
// [AppDialogFooter.single] is that foot, and there is no ANNULLA in this app
// that merely closes the window it is in.
class AppDialogFooter extends StatelessWidget
{
  // Half of this each, and no more however wide the window is. A dialog that
  // holds a list is over a thousand pixels across, and two buttons sharing that
  // between them came out five hundred wide apiece — a button the size of a
  // paragraph. Under it they still split what there is, which is what the
  // narrow windows have always done.
  static const double _maxWidth = 520;

  static const double _gap = 16;

  // Exactly the width one of the pair gets, so that the foot of a window with
  // one answer and the foot of a window with two are plainly the same foot. Let
  // out to the full width, a lone button reads as a banner across the bottom of
  // the window rather than as the thing you press.
  static const double _singleWidth = (_maxWidth - _gap) / 2;

  // Absent on a foot with a single button: see the class comment.
  final Widget? secondary;

  final Widget primary;

  const AppDialogFooter({
    super.key,
    required Widget this.secondary,
    required this.primary,
  });

  const AppDialogFooter.single(this.primary, {super.key}) : secondary = null;

  @override
  Widget build(BuildContext context)
  {
    final Widget? secondary = this.secondary;

    if (secondary == null)
    {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _singleWidth),
          // The buttons fill whatever they are given, and this is what gives
          // them the whole of it: without it the button is only as wide as its
          // own label, and the foot of the window would change width with the
          // word written on it.
          child: SizedBox(width: double.infinity, child: primary),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Row(
          children: [
            Expanded(child: secondary),
            const SizedBox(width: _gap),
            Expanded(child: primary),
          ],
        ),
      ),
    );
  }
}
