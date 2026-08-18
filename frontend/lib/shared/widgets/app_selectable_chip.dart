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

// One thing you can pick out of many. Chosen, it wears the brand ramp with a
// check on it — the same answer a filter pill gives when it is on, because it is
// the same statement: this one is in.
//
// Under the pointer it takes the gold outline every other pickable surface in
// the app takes, so a chip you have not chosen still tells you it can be.
//
// Which control a question is asked with is decided by how many answers there
// are, not by whether more than one can be picked — that is told by the label
// ("Aree (massimo 3)"), because it is the only signal that still reads when a
// single answer happens to be on.
//
//   two opposite answers              AppSegmentedSwitch
//   up to six, short and fixed        these chips — all visible at once
//   seven to twenty, or long answers  AppDropdownField
//   a list that grows with the data   MultiSelectFilterDialog, with its search
//
// Outside that scale sit the filter pills above a list (AppFilterPill): they do
// not answer a question inside a form, they shorten a list.
class AppSelectableChip extends StatefulWidget
{
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  // Off where the answer exists but cannot be given — a day a teacher is
  // already down for. It stays in the row, greyed and unpickable, because a
  // missing chip is a question you cannot ask about, while a dead one is an
  // answer with a reason.
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

  // The white is written as a ramp of two whites rather than as a plain colour.
  // It looks like a pointless way to say white, and it is the whole fix: a
  // decoration that carries a colour and one that carries a gradient cannot be
  // interpolated into each other, so the old chip had nothing to animate through
  // and flashed on its way between the two. Two gradients lerp colour by colour,
  // and the ramp simply grows out of the white.
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
              // Flexible and free to wrap: a study programme can be named at
              // length, and the name is the whole point of the chip. It runs on
              // to a second line and the chip grows to hold it, rather than
              // being cut short with a tooltip standing in for what was lost.
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

// The label of a chip, always laid out as though the chip had been picked.
//
// A picked chip sets its name in bold, and bold letters are wider. Measured from
// what is actually drawn, the chip therefore grew by a few pixels the moment it
// was picked: it shoved its neighbours along the row, and in a wrap it pushed
// whatever was last onto a line of its own — a whole block of chips rearranging
// itself under the finger that was only answering a question, and a dialog
// changing height as it did.
//
// So the chip is measured from copies that are never drawn — one per weight,
// the box being the wider of the two — and the copy that is drawn is laid over
// them. The box is the same box in every state — picked or not, and off as well,
// since a chip may be barred and freed again — and the letters merely thicken
// inside it.
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
    // What the visible copy will really be laid out with: a Text merges the
    // style it is handed into the DefaultTextStyle around it, and the copy the
    // chip is measured from has to be laid out with the very same thing or it
    // would not be measuring the same letters.
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    // The rules of layout, pinned for both copies before either is built.
    //
    // A Text takes maxLines, softWrap and overflow from the DefaultTextStyle
    // around it; the RichText the chip is measured from takes none of them. A
    // page asking for one line and an ellipsis therefore ruled the word you
    // read while the room it was given was measured without them — and where
    // the two disagreed, the word lost its end.
    //
    // Set here rather than on the Text, because maxLines cannot be cleared on
    // one: passing null asks to inherit, which is the very thing being undone.
    // A DefaultTextStyle replaces what is above it outright, so inside this one
    // there is nothing left to inherit.
    return DefaultTextStyle(
      style: inherited,
      textAlign: TextAlign.center,
      softWrap: true,
      overflow: TextOverflow.visible,
      child: _buildLayers(context, inherited),
    );
  }

  // One copy of the name, laid out and never painted. What the chip is sized to.
  //
  // Written as the RichText a Text would have built, rather than as a Text,
  // because it is a measurement and not a word on the screen: kept out of the
  // semantics so the name is not read aloud twice, and out of the way of
  // anything that goes looking for the label of a chip.
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
    // Both weights are laid out, and the box comes out the wider of the two —
    // the Stack takes the size of its largest child.
    //
    // Measuring the bold one alone rested on bold being the wider, which is true
    // of a typeface and not of what actually gets drawn: the two weights are two
    // separate downloads, and until both are in, one of them is being drawn in
    // whatever the platform substitutes. A regular that has not arrived is wider
    // than a bold that has, and the word then did not fit the box measured for
    // it — "30m", one word, broke after the "30" and put the "m" on a line of
    // its own.
    //
    // Both laid out at all times, so the box is still the same box whichever
    // state the chip is in, which is the whole point of measuring apart from
    // drawing.
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
