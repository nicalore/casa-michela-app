import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/shared_components.dart';
import 'person_detail_widgets.dart' show kObscuredLetterSpacing, kObscuredValue;

// A card whose whole content stays hidden until the eye in its head is opened.
class EyeMasked extends StatefulWidget
{
  final Widget Function(BuildContext context, bool hidden, Widget eye) builder;

  const EyeMasked({super.key, required this.builder});

  @override
  State<EyeMasked> createState() => _EyeMaskedState();
}

class _EyeMaskedState extends State<EyeMasked>
{
  bool _visible = false;

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    final Widget eye = FadeHoverIconButton(
      icon: _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: AppTheme.trialMutedText,
      hoverColor: AppTheme.trialGoldSurface,
      iconSize: dense ? 18 : 24,
      padding: dense ? 7 : 6,
      onTap: () => setState(() => _visible = !_visible),
    );

    return widget.builder(context, !_visible, eye);
  }
}

// The same ten dots whatever is hidden, so not even its length shows.
class ObscuredCardText extends StatelessWidget
{
  const ObscuredCardText({super.key});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    return Text(
      kObscuredValue,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 15 : 18,
        fontWeight: FontWeight.w700,
        letterSpacing: kObscuredLetterSpacing,
        color: AppTheme.trialInk,
      ),
    );
  }
}
