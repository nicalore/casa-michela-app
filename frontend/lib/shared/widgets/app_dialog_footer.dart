import 'package:flutter/material.dart';

class AppDialogFooter extends StatelessWidget
{
  static const double defaultWidth = 520;

  static const double _gap = 16;

  static double _halfOf(double width) => (width - _gap) / 2;

  final Widget? secondary;

  final Widget primary;

  final Widget? tertiary;

  final double maxWidth;

  const AppDialogFooter({
    super.key,
    required Widget this.secondary,
    required this.primary,
    this.tertiary,
    this.maxWidth = defaultWidth,
  });

  const AppDialogFooter.single(this.primary, {super.key, this.maxWidth = defaultWidth})
      : secondary = null,
        tertiary = null;

  @override
  Widget build(BuildContext context)
  {
    final Widget? secondary = this.secondary;

    if (secondary == null)
    {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _halfOf(maxWidth)),
          child: SizedBox(width: double.infinity, child: primary),
        ),
      );
    }

    final Widget? tertiary = this.tertiary;

    if (tertiary != null)
    {
      return Center(
        child: LayoutBuilder(
          builder: (context, constraints)
          {
            if (constraints.maxWidth < maxWidth)
            {
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: _gap,
                runSpacing: _gap,
                children: [tertiary, secondary, primary],
              );
            }

            return SizedBox(
              width: maxWidth,
              child: Row(
                children: [
                  Expanded(child: tertiary),
                  const SizedBox(width: _gap),
                  Expanded(child: secondary),
                  const SizedBox(width: _gap),
                  Expanded(child: primary),
                ],
              ),
            );
          },
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
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
