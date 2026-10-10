import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/settings/utils/settings_strings.dart';
import '../mobile_palette.dart';
import 'mobile_current_card.dart';
import 'mobile_glass_panel.dart';
import 'mobile_pill.dart';

const double _radius = 16;
const double _minHeight = 56;
const double _sidePadding = 14;
const double _gap = 12;

const double _restBorder = 1;

const double _tickSize = 24;

const double _previewRadius = 12;
// A one-line label row stays 46 tall around the tick.
const double _labelRowPadding = (46 - _tickSize) / 2;

// The preview's parts were drawn for this height and scale with it.
const double _drawnAt = 112;

const List<Color> _lightSea = [
  AppTheme.trialDeepWater,
  AppTheme.trialTealDeep,
  AppTheme.trialSeaGreen,
  AppTheme.trialLagoon,
];

const List<Color> _darkSea = [Color(0xFF050D15), Color(0xFF0A1B28), Color(0xFF0E2831)];

BoxDecoration _tileDecoration({required bool chosen})
{
  return BoxDecoration(
    color: chosen ? Colors.white : Colors.white.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(_radius),
    border: Border.all(
      color: chosen ? Colors.white : AppTheme.trialOcean.withValues(alpha: 0.1),
      width: _restBorder,
    ),
  );
}

// Drawn outside the tile, so the content keeps its place.
Decoration? _chosenRim({required bool chosen})
{
  return chosen ? const MobileCurrentCard(BorderRadius.all(Radius.circular(_radius))) : null;
}

TextStyle _labelStyle({required bool available, double fontSize = 16})
{
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: available ? FontWeight.w700 : FontWeight.w600,
    color: available ? AppTheme.trialInk : MobilePalette.mutedText,
  );
}

Widget _trailing({required bool chosen, required bool available})
{
  if (chosen)
  {
    return const MobileChoiceTick();
  }

  return available ? const SizedBox.shrink() : const MobilePill(kComingSoon, tone: MobilePillTone.muted);
}

class MobileChoiceTile extends StatelessWidget
{
  final Widget? leading;
  final String label;
  final bool chosen;
  final bool available;

  final String? eyebrow;
  final String? detail;

  const MobileChoiceTile({
    super.key,
    this.leading,
    required this.label,
    required this.chosen,
    this.available = true,
    this.eyebrow,
    this.detail,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget? leading = this.leading;

    return Semantics(
      selected: chosen,
      enabled: available,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minHeight),
        padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
        decoration: _tileDecoration(chosen: chosen),
        foregroundDecoration: _chosenRim(chosen: chosen),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: _gap),
            ],
            Expanded(child: _buildText()),
            const SizedBox(width: 8),
            _trailing(chosen: chosen, available: available),
          ],
        ),
      ),
    );
  }

  Widget _buildText()
  {
    final String? eyebrow = this.eyebrow;
    final String? detail = this.detail;

    if (eyebrow == null && detail == null)
    {
      return Text(label, style: _labelStyle(available: available));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppTheme.trialTealDeep,
                ),
              ),
            ),
          Text(label, style: _labelStyle(available: available, fontSize: 15.5)),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                detail,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: MobilePalette.mutedText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MobileChoiceTick extends StatelessWidget
{
  const MobileChoiceTick({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _tickSize,
      height: _tickSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.trialGold, Color(0xFFF3C766)],
        ),
        boxShadow: [
          BoxShadow(color: AppTheme.trialGold.withValues(alpha: 0.35), offset: const Offset(0, 3), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.check_rounded, size: 16, color: AppTheme.trialDeepWater),
    );
  }
}

class MobileThemeTile extends StatelessWidget
{
  final String label;
  final bool dark;
  final bool chosen;
  final bool available;

  final double previewHeight;

  const MobileThemeTile({
    super.key,
    required this.label,
    required this.dark,
    required this.chosen,
    this.available = true,
    this.previewHeight = _drawnAt,
  });

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      selected: chosen,
      enabled: available,
      label: label,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        decoration: _tileDecoration(chosen: chosen),
        foregroundDecoration: _chosenRim(chosen: chosen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ThemePreview(dark: dark, height: previewHeight),
            // Takes its neighbour's height when the badge has to go under the label.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, _labelRowPadding, 4, _labelRowPadding),
                child: Align(
                  alignment: Alignment.topLeft,
                  // Full width, so a badge that fits keeps to the far end.
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // As tall as the tick, so both tiles' labels stand on one line.
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: _tickSize),
                          child: Align(
                            widthFactor: 1,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              style: _labelStyle(available: available, fontSize: 15.5).copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        _trailing(chosen: chosen, available: available),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget
{
  final bool dark;
  final double height;

  const _ThemePreview({required this.dark, required this.height});

  Widget _bar(double height, Color color, {double? width})
  {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double s = height / _drawnAt;

    final Color card = dark ? const Color(0xE6284054) : Colors.white.withValues(alpha: 0.66);
    final Color dash = Colors.white.withValues(alpha: 0.45);

    Widget miniCard(double h)
    {
      return Container(
        height: h * s,
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(6 * s)),
      );
    }

    return ExcludeSemantics(
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_previewRadius),
          gradient: dark
              ? const LinearGradient(
                  begin: Alignment(-0.6, -1),
                  end: Alignment(0.6, 1),
                  colors: _darkSea,
                  stops: [0, 0.55, 1],
                )
              : const LinearGradient(
                  begin: Alignment(-0.6, -1),
                  end: Alignment(0.6, 1),
                  colors: _lightSea,
                  stops: [0, 0.45, 0.75, 1],
                ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(10 * s, 11 * s, 10 * s, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.54,
                    child: _bar(7 * s, Colors.white.withValues(alpha: dark ? 0.85 : 0.92)),
                  ),
                  SizedBox(height: 7 * s),
                  Row(
                    children: [
                      _bar(3 * s, AppTheme.trialGold, width: 17 * s),
                      SizedBox(width: 5 * s),
                      _bar(3 * s, dash, width: 17 * s),
                      SizedBox(width: 5 * s),
                      _bar(3 * s, dash, width: 17 * s),
                    ],
                  ),
                  SizedBox(height: 7 * s),
                  miniCard(18),
                  SizedBox(height: 6 * s),
                  miniCard(26),
                  SizedBox(height: 6 * s),
                  miniCard(18),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 11 * s,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF1C3040)
                      : MobileGlassPanel.sheetTint.withValues(alpha: MobileGlassPanel.sheetAlpha),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6 * s)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MobileSwatches extends StatelessWidget
{
  static const double _size = 22;
  static const double _step = 15;

  final List<Color> colors;

  const MobileSwatches({super.key, required this.colors});

  @override
  Widget build(BuildContext context)
  {
    return ExcludeSemantics(
      child: SizedBox(
        width: _size + _step * (colors.length - 1),
        height: _size,
        child: Stack(
          children: [
            for (var i = 0; i < colors.length; i++)
              Positioned(
                left: _step * i,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i],
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 1), blurRadius: 3)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MobileLanguageCode extends StatelessWidget
{
  final String code;
  final bool available;

  const MobileLanguageCode({super.key, required this.code, this.available = true});

  @override
  Widget build(BuildContext context)
  {
    final Color tint = available ? AppTheme.trialTealDeep : MobilePalette.mutedText;

    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint.withValues(alpha: available ? 0.13 : 0.1),
        ),
        child: Text(
          code,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: tint,
          ),
        ),
      ),
    );
  }
}
