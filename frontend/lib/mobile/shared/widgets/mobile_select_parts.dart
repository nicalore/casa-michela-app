import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';

const Duration _press = Duration(milliseconds: 160);

const double kMobileChipGap = 6;

const double _rowRadius = 16;
const double _rowMinHeight = 50;
const Color _rowRest = Color(0xB8FFFFFF);
const double _rowEdgeAlpha = 0.06;

const double _ringSize = 24;
const double _ringEdge = 2;
const double _ringEdgeAlpha = 0.2;

const double _toggleSize = 26;
// Centres the toggle over the rows' rings: 14 of padding plus half a ring.
const double _toggleBoxWidth = 52;
const double _toggleBoxHeight = 40;

// Both ends are gradients, as a colour and a gradient cannot interpolate.
LinearGradient mobileSelectFill(Color rest, double t)
{
  return LinearGradient(
    begin: AppTheme.brandGradient.begin,
    end: AppTheme.brandGradient.end,
    colors: [
      Color.lerp(rest, AppTheme.trialTealDeep, t)!,
      Color.lerp(rest, AppTheme.trialTurquoise, t)!,
    ],
  );
}

Widget _taken({required bool selected, required Widget Function(double t) builder})
{
  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: selected ? 1 : 0, end: selected ? 1 : 0),
    duration: _press,
    curve: Curves.easeOut,
    builder: (context, t, _) => builder(t),
  );
}

// No tick: it would change the chip's width.
class MobileSelectChip extends StatelessWidget
{
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const MobileSelectChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _taken(
          selected: selected,
          builder: (t) => Container(
            height: 38,
            // Tight enough for three of the lesson kinds to share a phone's row.
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              gradient: mobileSelectFill(Colors.white, t),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AppTheme.trialInk.withValues(alpha: 0.12 * (1 - t))),
            ),
            child: Align(
              widthFactor: 1,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color.lerp(AppTheme.trialInk, Colors.white, t),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Its ring is always there, so the row never changes width.
class MobileSelectRow extends StatelessWidget
{
  final String title;
  final String? subtitle;
  final bool selected;

  final Widget? leading;

  final VoidCallback onTap;

  const MobileSelectRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    this.leading,
    required this.onTap,
  });

  Widget _buildTexts(double t)
  {
    final String? subtitle = this.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: Color.lerp(AppTheme.trialInk, Colors.white, t),
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: Color.lerp(MobilePalette.mutedText, Colors.white.withValues(alpha: 0.85), t),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget? leading = this.leading;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _taken(
          selected: selected,
          builder: (t) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            padding: EdgeInsets.fromLTRB(leading == null ? 14 : 10, 10, 14, 10),
            decoration: BoxDecoration(
              gradient: mobileSelectFill(_rowRest, t),
              borderRadius: BorderRadius.circular(_rowRadius),
              border: Border.all(color: AppTheme.trialInk.withValues(alpha: _rowEdgeAlpha * (1 - t))),
              boxShadow: t == 0
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.trialTealDeep.withValues(alpha: 0.22 * t),
                        offset: const Offset(0, 6),
                        blurRadius: 14,
                      ),
                    ],
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 14),
                ],
                Expanded(child: _buildTexts(t)),
                const SizedBox(width: 12),
                _Ring(t: t),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget
{
  final double t;

  const _Ring({required this.t});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _ringSize,
      height: _ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: t),
        border: Border.all(color: AppTheme.trialInk.withValues(alpha: _ringEdgeAlpha * (1 - t)), width: _ringEdge),
      ),
      child: Icon(Icons.check_rounded, size: 16, color: AppTheme.trialTealDeep.withValues(alpha: t)),
    );
  }
}

class MobileSelectAllToggle extends StatelessWidget
{
  final bool selected;
  final bool partial;
  final VoidCallback onTap;

  const MobileSelectAllToggle({super.key, required this.selected, required this.partial, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    final bool filled = selected || partial;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _toggleBoxWidth,
          height: _toggleBoxHeight,
          child: Center(
            child: _taken(
              selected: filled,
              builder: (t) => Container(
                width: _toggleSize,
                height: _toggleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: mobileSelectFill(Colors.white.withValues(alpha: 0), t),
                  border: Border.all(
                    color: AppTheme.trialInk.withValues(alpha: _ringEdgeAlpha * (1 - t)),
                    width: _ringEdge,
                  ),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.remove_rounded,
                  size: 17,
                  color: Colors.white.withValues(alpha: t),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MobileSelectGroupHead extends StatelessWidget
{
  final String title;
  final List<Widget> trailing;

  const MobileSelectGroupHead({super.key, required this.title, this.trailing = const []});

  @override
  Widget build(BuildContext context)
  {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.trialInk.withValues(alpha: 0.62),
            ),
          ),
        ),
        ...trailing,
      ],
    );
  }
}
