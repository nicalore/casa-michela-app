import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Duration _fade = Duration(milliseconds: 220);
const double _radius = 22;
const double _borderWidth = 1.5;

const double _fontSize = 14;
const double _lineHeight = 1.25;

// The two weights a chip is set in. Which one is drawn depends on whether the
// chip is chosen; how big the chip is does not, and that is what [_ChipLabel] is
// for.
const FontWeight _restWeight = FontWeight.w500;
const FontWeight _chosenWeight = FontWeight.w700;

// One thing you can pick out of many. Which control a question uses is decided
// by how many answers there are, not by whether more than one can be picked —
// the label says that ("Aree (massimo 3)").
//
//   two opposite answers              AppSegmentedSwitch
//   up to six, short and fixed        these chips — all visible at once
//   seven to twenty, or long answers  AppDropdownField
//   a list that grows with the data   MultiSelectFilterDialog, with its search
//
// The filter pills above a list shorten a list rather than answering.
class AppSelectableChip extends StatefulWidget
{
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  // Off where the answer exists but cannot be given. It stays in the row: a
  // missing chip is a question you cannot ask about, a dead one has a reason.
  final bool enabled;

  // Why it is off, said on hover. Reaches nobody where the chip is on, so it
  // is only worth passing with [enabled] false.
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

  // A ramp of two whites and not a plain colour: a decoration carrying a colour
  // and one carrying a gradient cannot be interpolated, so the chip flashed on
  // its way between the two.
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

    // Two values, because the two answers are to two different questions and can
    // be halfway through at the same time: t is whether it is chosen, h is
    // whether the pointer is on it.
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

  // Struck through and on the paper's own grey: it reads as a thing that is
  // spoken for, rather than as one waiting to be pressed.
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
          // The colour is the whole message: a chip that has gone from white to
          // the brand ramp has already said it is in, and a tick on top of that
          // says it twice.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Free to wrap: the name is the whole point of the chip, so it
              // runs to a second line rather than being cut with a tooltip.
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

// The label, always laid out as though the chip had been picked: bold is wider,
// so measured from what is drawn the chip grew when picked and shoved its
// neighbours. Measured instead from copies never drawn, one per weight, with the
// drawn one laid over them — the letters thicken inside the same box.
class _ChipLabel extends StatelessWidget
{
  final String label;

  // The weight the letters are drawn at. Not the one they are measured at: the
  // box is measured at both, which is the whole point of this.
  final FontWeight weight;

  final Color color;

  // Struck through, for a chip that is there but cannot be picked.
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
    // A Text merges its style into the DefaultTextStyle around it, and the copy
    // being measured has to be laid out with the same thing.
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    // Pinned for both copies: a Text takes maxLines and overflow from the
    // DefaultTextStyle while the measured RichText takes none, so the word was
    // ruled by them and the room was not. Here and not on the Text, where
    // maxLines cannot be cleared — null asks to inherit.
    return DefaultTextStyle(
      style: inherited,
      textAlign: TextAlign.center,
      softWrap: true,
      overflow: TextOverflow.visible,
      child: _buildLayers(context, inherited),
    );
  }

  // One copy of the name, laid out and never painted, which is what the chip is
  // sized to. A RichText and not a Text because it is a measurement: out of the
  // semantics, so the name is not read aloud twice.
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
    // Both weights laid out, the box being the wider. Measuring the bold alone
    // rested on bold being wider, true of a typeface and not of what gets drawn:
    // the two are separate downloads, and a regular that has not arrived is
    // wider than a bold that has.
    return Stack(
      // And nothing here cuts a letter off either. Where the copies still
      // disagree by a hair, that hair paints into the chip's own padding, where
      // there is room to spare and nobody can see it.
      clipBehavior: Clip.none,
      children: [
        _measure(context, inherited, _restWeight),
        _measure(context, inherited, _chosenWeight),
        // Centred in what was measured, because a name set lighter than the box
        // it is laid in would otherwise sit against the top left of it and leave
        // the chip looking as though its padding had come loose.
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
