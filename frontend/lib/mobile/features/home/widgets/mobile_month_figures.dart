import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/home/models/month_summary_items.dart';
import '../../../../features/home/widgets/home_month_section.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';

const int _monthlyThreshold = 9;
const int _weeklyThreshold = 2;

const double _leadSize = 64;
const double _gaugeStroke = 7;
const double _rowGap = 10;

const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(24));
const EdgeInsets _rowPadding = EdgeInsets.fromLTRB(18, 14, 18, 14);

class MobileMonthFigures extends StatelessWidget
{
  final TeacherMonthSummaryItem month;

  const MobileMonthFigures({super.key, required this.month});

  Widget _leadFor(int index, HomeFigure figure)
  {
    switch (index)
    {
      case 0:
        return _Gauge(
          fraction: month.totalAvailabilities / _monthlyThreshold,
          label: '${figure.value}/$_monthlyThreshold',
          warning: month.isBelowMonthlyThreshold,
        );

      case 1:
        return _Gauge(
          fraction: month.weeklyAvailabilities / _weeklyThreshold,
          label: '${figure.value}/$_weeklyThreshold',
          warning: figure.warning != null,
        );

      case 2:
        return const _LeadIcon(Icons.school_rounded);

      default:
        return const _LeadIcon(Icons.payments_rounded);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final List<HomeFigure> figures = teacherFigures(month);

    return _Rows([
      for (var i = 0; i < figures.length; i++) _FigureRow(lead: _leadFor(i, figures[i]), figure: figures[i]),
    ]);
  }
}

// Presenze, Prenotazioni, Lezioni and Modalità, in pupilFigures order.
const List<IconData> _pupilIcons = [
  Icons.how_to_reg_rounded,
  Icons.bookmark_added_rounded,
  Icons.school_rounded,
  Icons.sell_rounded,
];

class MobilePupilMonthFigures extends StatelessWidget
{
  final List<HomeFigure> figures;

  const MobilePupilMonthFigures({super.key, required this.figures});

  @override
  Widget build(BuildContext context)
  {
    return _Rows([
      for (final (i, figure) in figures.indexed)
        _FigureRow(lead: _LeadIcon(_pupilIcons[i % _pupilIcons.length]), figure: figure),
    ]);
  }
}

class _Rows extends StatelessWidget
{
  final List<Widget> rows;

  const _Rows(this.rows);

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _rowGap),
          rows[i],
        ],
      ],
    );
  }
}

class _FigureRow extends StatelessWidget
{
  final Widget lead;
  final HomeFigure figure;

  const _FigureRow({required this.lead, required this.figure});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: _rowPadding,
      borderRadius: _rowRadius,
      child: Row(
        children: [
          SizedBox(width: _leadSize, height: _leadSize, child: lead),
          const SizedBox(width: 16),
          Expanded(child: _FigureText(figure: figure)),
        ],
      ),
    );
  }
}

class _FigureText extends StatelessWidget
{
  final HomeFigure figure;

  const _FigureText({required this.figure});

  Widget _buildAside()
  {
    final String? warning = figure.warning;

    if (warning != null)
    {
      return _Aside(
        icon: Icons.warning_rounded,
        text: warning,
        color: AppTheme.modifiedAccent,
      );
    }

    final HomeDelta? delta = figure.delta;

    if (delta == null)
    {
      return const SizedBox.shrink();
    }

    return switch (delta.direction)
    {
      > 0 => _Aside(icon: Icons.trending_up_rounded, text: delta.text, color: AppTheme.trialSeaGreen),
      < 0 => _Aside(icon: Icons.trending_down_rounded, text: delta.text, color: AppTheme.trialDanger),
      _ => _Aside(icon: Icons.trending_flat_rounded, text: delta.text, color: MobilePalette.mutedText),
    };
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: figure.value,
            children: [
              if (figure.unit.isNotEmpty)
                TextSpan(
                  text: ' ${figure.unit}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: MobilePalette.mutedText,
                  ),
                ),
            ],
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: figure.isWord ? 24 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: figure.isWord ? -0.3 : -0.6,
            height: 1.05,
            color: switch (figure.tone)
            {
              HomeFigureTone.plain => AppTheme.trialInk,
              HomeFigureTone.pending => AppTheme.trialTealDeep,
              HomeFigureTone.absent => MobilePalette.mutedText,
            },
          ),
        ),
        const SizedBox(height: 3),
        Text(
          figure.label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.trialInk.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 4),
        _buildAside(),
      ],
    );
  }
}

class _Aside extends StatelessWidget
{
  final IconData icon;
  final String text;
  final Color color;

  const _Aside({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context)
  {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeadIcon extends StatelessWidget
{
  final IconData icon;

  const _LeadIcon(this.icon);

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.5),
      ),
      child: Icon(icon, size: 28, color: AppTheme.trialTealDeep),
    );
  }
}

class _Gauge extends StatelessWidget
{
  final double fraction;
  final String label;
  final bool warning;

  const _Gauge({required this.fraction, required this.label, required this.warning});

  @override
  Widget build(BuildContext context)
  {
    return CustomPaint(
      painter: _GaugePainter(
        fraction: fraction.clamp(0, 1),
        color: warning ? AppTheme.trialGold : AppTheme.trialTurquoise,
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialInk,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter
{
  final double fraction;
  final Color color;

  const _GaugePainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size)
  {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - _gaugeStroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.trialInk.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _gaugeStroke,
    );

    if (fraction > 0)
    {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _gaugeStroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate)
  {
    return fraction != oldDelegate.fraction || color != oldDelegate.color;
  }
}
