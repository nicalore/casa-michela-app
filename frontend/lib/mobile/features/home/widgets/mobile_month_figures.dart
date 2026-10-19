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

const double _compactLeadSize = 40;
const double _compactRowGap = 8;

const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(24));
const EdgeInsets _rowPadding = EdgeInsets.fromLTRB(18, 14, 18, 14);
const EdgeInsets _compactRowPadding = EdgeInsets.fromLTRB(10, 7, 16, 7);

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

// "Presenze", "Prenotazioni", "Lezioni" and "Modalità", in pupilFigures order.
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

// "Iscritti", "Collaboratori", "Docenti" and "Studenti", in dashboardStats order.
const List<IconData> _associationIcons = [
  Icons.badge_rounded,
  Icons.volunteer_activism_rounded,
  Icons.co_present_rounded,
  Icons.backpack_rounded,
];

class MobileAssociationMonthFigures extends StatelessWidget
{
  final List<HomeFigure> figures;

  // Tablets: lower rows with the change beside the figure, so the day beside them stretches less.
  final bool compact;

  const MobileAssociationMonthFigures({super.key, required this.figures, this.compact = false});

  @override
  Widget build(BuildContext context)
  {
    return _Rows(
      [
        for (final (i, figure) in figures.indexed)
          _FigureRow(
            lead: _LeadIcon(_associationIcons[i % _associationIcons.length], size: compact ? 20 : 28),
            figure: figure,
            compact: compact,
          ),
      ],
      gap: compact ? _compactRowGap : _rowGap,
    );
  }
}

class _Rows extends StatelessWidget
{
  final List<Widget> rows;
  final double gap;

  const _Rows(this.rows, {this.gap = _rowGap});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
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
  final bool compact;

  const _FigureRow({required this.lead, required this.figure, this.compact = false});

  @override
  Widget build(BuildContext context)
  {
    final double lead = compact ? _compactLeadSize : _leadSize;

    return MobileGlassPanel(
      padding: compact ? _compactRowPadding : _rowPadding,
      borderRadius: _rowRadius,
      child: Row(
        children: [
          SizedBox(width: lead, height: lead, child: this.lead),
          SizedBox(width: compact ? 14 : 16),
          Expanded(child: _FigureText(figure: figure, compact: compact)),
          if (compact) ...[
            const SizedBox(width: 10),
            _asideOf(figure, shrink: true),
          ],
        ],
      ),
    );
  }
}

Widget _asideOf(HomeFigure figure, {bool shrink = false})
{
  final String? warning = figure.warning;

  if (warning != null)
  {
    return _Aside(
      icon: Icons.warning_rounded,
      text: warning,
      color: AppTheme.modifiedAccent,
      shrink: shrink,
    );
  }

  final HomeDelta? delta = figure.delta;

  if (delta == null)
  {
    return const SizedBox.shrink();
  }

  final (IconData icon, Color color) = switch (delta.direction)
  {
    > 0 => (Icons.trending_up_rounded, AppTheme.trialSeaGreen),
    < 0 => (Icons.trending_down_rounded, AppTheme.trialDanger),
    _ => (Icons.remove_rounded, MobilePalette.mutedText),
  };

  return _Aside(icon: icon, text: delta.text, color: color, shrink: shrink);
}

class _FigureText extends StatelessWidget
{
  final HomeFigure figure;

  // The change then sits beside the text, not under it.
  final bool compact;

  const _FigureText({required this.figure, this.compact = false});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (final part in figure.parts)
                TextSpan(
                  text: part.text,
                  style: part.isUnit
                      ? GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: MobilePalette.mutedText,
                        )
                      : null,
                ),
            ],
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: figure.isWord ? 24 : (compact ? 23 : 30),
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
        SizedBox(height: compact ? 2 : 3),
        Text(
          figure.label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: compact ? 10.5 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.trialInk.withValues(alpha: 0.62),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          _asideOf(figure),
        ],
      ],
    );
  }
}

class _Aside extends StatelessWidget
{
  final IconData icon;
  final String text;
  final Color color;

  // As wide as its text, for a row that leaves it no fixed width.
  final bool shrink;

  const _Aside({required this.icon, required this.text, required this.color, this.shrink = false});

  @override
  Widget build(BuildContext context)
  {
    final Widget label = Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );

    return Row(
      mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        if (shrink) label else Flexible(child: label),
      ],
    );
  }
}

class _LeadIcon extends StatelessWidget
{
  final IconData icon;
  final double size;

  const _LeadIcon(this.icon, {this.size = 28});

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.5),
      ),
      child: Icon(icon, size: size, color: AppTheme.trialTealDeep),
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
