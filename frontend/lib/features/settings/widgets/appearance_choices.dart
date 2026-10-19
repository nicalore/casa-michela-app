import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../utils/settings_strings.dart';

const double _themeWidth = 236;
const double _themePreview = 126;
const double _themeRadius = 20;
const double _themePadding = 10;

const double _paletteWidth = 156;
const double _paletteBar = 34;
const double _paletteRadius = 16;
const double _palettePadding = 9;

const double _border = 2;
const double _chosenBorder = 3;
const double _chosenHalo = 4;

const double _unavailableOpacity = 0.6;

const Color _darkScreen = Color(0xFF0E2133);
const Color _darkPart = Color(0xFF1A3550);
const Color _darkLine = Color(0xFF355674);
const Color _lightLine = Color(0xFFC9D6DC);

// A chosen tile keeps its size: the thicker rim eats into the padding.
BoxDecoration _tileDecoration({required bool chosen, required double radius})
{
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: chosen ? AppTheme.trialTurquoise : AppTheme.trialLine,
      width: chosen ? _chosenBorder : _border,
    ),
    boxShadow: chosen
        ? [BoxShadow(color: AppTheme.trialTurquoise.withValues(alpha: 0.14), spreadRadius: _chosenHalo)]
        : null,
  );
}

EdgeInsets _tilePadding(double padding, {required bool chosen})
{
  return EdgeInsets.all(padding - (chosen ? _chosenBorder - _border : 0));
}

Widget _chosenTick(double size) => Icon(Icons.check_circle_rounded, size: size, color: AppTheme.trialTurquoise);

class ThemePreviewTile extends StatelessWidget
{
  final String label;
  final bool dark;
  final bool chosen;
  final bool available;

  const ThemePreviewTile({
    super.key,
    required this.label,
    required this.dark,
    required this.chosen,
    required this.available,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget tile = Container(
      width: _themeWidth,
      padding: _tilePadding(_themePadding, chosen: chosen),
      decoration: _tileDecoration(chosen: chosen, radius: _themeRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(height: _themePreview, child: _MiniScreen(dark: dark)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialOcean,
                  ),
                ),
                const Spacer(),
                if (chosen) _chosenTick(20),
              ],
            ),
          ),
        ],
      ),
    );

    if (available)
    {
      return tile;
    }

    return AppTooltip(
      waitDuration: kComingSoonWait,
      message: kComingSoon,
      child: Opacity(opacity: _unavailableOpacity, child: tile),
    );
  }
}

class _MiniScreen extends StatelessWidget
{
  final bool dark;

  const _MiniScreen({required this.dark});

  Widget _part(double left, double top, double width, double height, {double radius = 10})
  {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? _darkPart : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _line(double top, double width)
  {
    return Positioned(
      left: 18,
      top: top,
      width: width,
      height: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? _darkLine : _lightLine,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Color glow = dark ? AppTheme.trialTurquoise : AppTheme.trialDeepWater;

    return ColoredBox(
      color: dark ? _darkScreen : AppTheme.trialPaper,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -60,
            top: -60,
            width: 180,
            height: 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [glow.withValues(alpha: dark ? 0.25 : 0.3), glow.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          _part(10, 14, 44, 98),
          _line(22, 24),
          _line(34, 28),
          _line(46, 24),
          _part(64, 14, 84, 48),
          _part(156, 14, 84, 48),
          _part(64, 70, 176, 48),
        ],
      ),
    );
  }
}

class PaletteTile extends StatelessWidget
{
  final String label;
  final List<Color> colors;
  final bool chosen;

  const PaletteTile({super.key, required this.label, required this.colors, required this.chosen});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _paletteWidth,
      padding: _tilePadding(_palettePadding, chosen: chosen),
      decoration: _tileDecoration(chosen: chosen, radius: _paletteRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: _paletteBar,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final Color color in colors) Expanded(child: ColoredBox(color: color)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.trialOcean,
                    ),
                  ),
                ),
                if (chosen) _chosenTick(19),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageCode extends StatelessWidget
{
  final String code;
  final bool available;
  final double size;

  const LanguageCode({super.key, required this.code, this.available = true, this.size = 30});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: available ? AppTheme.brandGradient : null,
        color: available ? null : AppTheme.slate400,
      ),
      child: Text(
        code,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
