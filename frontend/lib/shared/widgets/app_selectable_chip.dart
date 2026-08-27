import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Duration _fade = Duration(milliseconds: 220);
const double _radius = 22;
const double _borderWidth = 1.5;

const double _fontSize = 14;
const double _lineHeight = 1.25;

const FontWeight _restWeight = FontWeight.w500;
const FontWeight _chosenWeight = FontWeight.w700;

// Which control asks a question: 2 opposites = AppSegmentedSwitch; up to 6 short
// fixed = these chips; 7-20 or long = AppDropdownField; growing lists = MultiSelectFilterDialog.
class AppSelectableChip extends StatefulWidget
{
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  final bool enabled;

  final String? disabledTooltip;

  const AppSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.disabledTooltip,
  });

  @override
  State<AppSelectableChip> createState() => _AppSelectableChipState();
}

class _AppSelectableChipState extends State<AppSelectableChip>
{
  bool _hover = false;

  // A decoration with a colour and one with a gradient cannot be interpolated:
  // both ends are gradients to avoid a flash.
  LinearGradient _gradient(double t)
  {
    return LinearGradient(
      begin: AppTheme.brandGradient.begin,
      end: AppTheme.brandGradient.end,
      colors: [
        Color.lerp(Colors.white, AppTheme.trialTealDeep, t)!,
        Color.lerp(Colors.white, AppTheme.trialTurquoise, t)!,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (!widget.enabled)
    {
      return _buildDisabledChip();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _hover ? 1 : 0),
      duration: _fade,
      curve: Curves.easeOut,
      builder: (context, h, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: widget.selected ? 1 : 0),
        duration: _fade,
        curve: Curves.easeOut,
        builder: (context, t, _) => _buildChip(t, h),
      ),
    );
  }

  Widget _buildDisabledChip()
  {
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.closedSurface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppTheme.closedLine, width: _borderWidth),
      ),
      child: _ChipLabel(
        label: widget.label,
        weight: _restWeight,
        color: AppTheme.trialMutedText,
        struck: true,
      ),
    );

    final tooltip = widget.disabledTooltip;

    if (tooltip == null)
    {
      return chip;
    }

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: chip,
    );
  }

  Widget _buildChip(double t, double h)
  {
    final Color contentColor = Color.lerp(
      Color.lerp(AppTheme.trialMutedText, AppTheme.trialTealDeep, h)!,
      Colors.white,
      t,
    )!;

    final Color borderColor = Color.lerp(
      Color.lerp(AppTheme.trialLine, Colors.transparent, t)!,
      AppTheme.trialGold,
      h,
    )!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.selected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: _gradient(t),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: borderColor, width: _borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _ChipLabel(
                  label: widget.label,
                  weight: t > 0.5 ? _chosenWeight : _restWeight,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sized from unpainted copies at both weights, so a picked (bold) chip does
// not grow and shove its neighbours.
class _ChipLabel extends StatelessWidget
{
  final String label;

  final FontWeight weight;

  final Color color;

  final bool struck;

  const _ChipLabel({
    required this.label,
    required this.weight,
    required this.color,
    this.struck = false,
  });

  TextStyle _style(FontWeight weight)
  {
    return GoogleFonts.plusJakartaSans(
      fontSize: _fontSize,
      fontWeight: weight,
      height: _lineHeight,
      color: color,
      decoration: struck ? TextDecoration.lineThrough : null,
      decorationColor: struck ? color : null,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    // Pinned for both copies: a Text takes maxLines/overflow from the
    // DefaultTextStyle while the measured RichText takes none.
    return DefaultTextStyle(
      style: inherited,
      textAlign: TextAlign.center,
      softWrap: true,
      overflow: TextOverflow.visible,
      child: _buildLayers(context, inherited),
    );
  }

  // A RichText, not a Text: a measurement, kept out of the semantics.
  Widget _measure(BuildContext context, TextStyle inherited, FontWeight weight)
  {
    return ExcludeSemantics(
      child: Opacity(
        opacity: 0,
        child: RichText(
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(context),
          text: TextSpan(
            text: label,
            style: inherited.merge(_style(weight)),
          ),
        ),
      ),
    );
  }

  Widget _buildLayers(BuildContext context, TextStyle inherited)
  {
    // Both weights are laid out; a regular that has not arrived can be wider
    // than a bold that has.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _measure(context, inherited, _restWeight),
        _measure(context, inherited, _chosenWeight),
        Positioned.fill(
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              textScaler: MediaQuery.textScalerOf(context),
              overflow: TextOverflow.visible,
              style: _style(weight),
            ),
          ),
        ),
      ],
    );
  }
}
