import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';
import '../models/month_summary_items.dart';

// How a figure is written: a number, a figure the backend cannot give yet, or
// a column kept for a sibling's sake with nothing in it.
enum HomeFigureTone { plain, pending, absent }

// How a figure moved against the month before, up to the same day.
class HomeDelta
{
  // "+2 giorni", "−0.5 ore", "€ 40,00"; "Stabile" when nothing moved.
  final String text;

  // Positive up, negative down, zero still.
  final int direction;

  const HomeDelta({required this.text, required this.direction});

  static const HomeDelta still = HomeDelta(text: 'Stabile', direction: 0);
}

// One figure on the month card.
class HomeFigure
{
  final String label;
  final String value;

  // Written after the value, in its own type: "5 giorni".
  final String unit;

  // Under the value, the warning if there is one, else the move.
  final String? warning;
  final HomeDelta? delta;

  final HomeFigureTone tone;

  const HomeFigure({
    required this.label,
    required this.value,
    this.unit = '',
    this.warning,
    this.delta,
    this.tone = HomeFigureTone.plain,
  });

  bool get hasAside => warning != null || delta != null;

  bool get pending => tone == HomeFigureTone.pending;

  // A word rather than a number is written smaller, so it fits its slot.
  bool get isWord => value.contains(RegExp(r'[a-zA-Z]'));

  String get text => unit.isEmpty ? value : '$value $unit';
}

// A person's figures; named only when the card speaks for several people.
class HomeFigureGroup
{
  final String name;
  final List<HomeFigure> figures;

  const HomeFigureGroup({required this.name, required this.figures});
}

// Hours as a number, since the note under it says they are hours: 90
// minutes read 1.5, a quarter 0.25.
String _hours(int minutes)
{
  final String text = (minutes / 60).toStringAsFixed(2);

  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

// Units agree with their number: one day, half a day, two days.
String _days(num count) => count == 1 ? 'giorno' : 'giorni';

String _hoursUnit(num count) => count == 1 ? 'ora' : 'ore';

// A signed move, "+2 giorni" or "−1 ora"; the minus is the typographic one.
// The unit is asked of the amount moved, so it agrees with it.
HomeDelta _delta(
  num change,
  String Function(num) write, {
  String Function(num)? unit,
})
{
  if (change == 0)
  {
    return HomeDelta.still;
  }

  final num amount = change.abs();
  final String sign = change > 0 ? '+' : '−';
  final String text = '$sign${write(amount)}';

  return HomeDelta(
    text: unit == null ? text : '$text ${unit(amount)}',
    direction: change > 0 ? 1 : -1,
  );
}

List<HomeFigure> teacherFigures(TeacherMonthSummaryItem month)
{
  final TeacherMonthFiguresItem last = month.lastMonth;

  final String? rate = month.grossCompensation;
  final int? cents = rate == null ? null : parseAmountCents(rate);
  final int? lastCents = last.grossCompensation == null
      ? null
      : parseAmountCents(last.grossCompensation!);

  // A tenth of a day is the finest the average is written in.
  final int weeklyTenths =
      (month.weeklyAvailabilities * 10).round() - (last.weeklyAvailabilities * 10).round();

  return [
    // Four in a row at half a page leaves each label about a hundred
    // pixels: the words are kept short enough to stand on one line.
    HomeFigure(
      label: 'Disponibilità',
      value: '${month.totalAvailabilities}',
      unit: _days(month.totalAvailabilities),
      warning: month.isBelowMonthlyThreshold ? 'Meno di 9' : null,
      delta: _delta(
        month.totalAvailabilities - last.totalAvailabilities,
        (change) => '$change',
        unit: _days,
      ),
    ),
    HomeFigure(
      label: 'A settimana',
      value: month.weeklyAvailabilities.toStringAsFixed(1),
      unit: _days(month.weeklyAvailabilities),
      warning: month.isBelowWeeklyThreshold ? 'Meno di 2' : null,
      delta: _delta(
        weeklyTenths,
        (change) => (change / 10).toStringAsFixed(1),
        unit: (change) => _days(change / 10),
      ),
    ),
    HomeFigure(
      label: 'Lezioni',
      value: _hours(month.workedMinutes),
      unit: _hoursUnit(month.workedMinutes / 60),
      delta: _delta(
        month.workedMinutes - last.workedMinutes,
        (change) => _hours(change.toInt()),
        unit: (change) => _hoursUnit(change / 60),
      ),
    ),
    // Only a paid collaboration has an hourly rate to multiply.
    if (cents != null)
      HomeFigure(
        label: 'Compenso',
        value: formatAmount(cents),
        delta: _delta(cents - (lastCents ?? 0), (change) => formatAmount(change.toInt())),
      ),
  ];
}

// How the pupil's hours are paid for. A package will show the hours left
// in it once the backend keeps count; until then it says so.
HomeFigure _tariffFigure(PupilMonthFiguresItem figures)
{
  if (figures.hasPackage)
  {
    return const HomeFigure(
      label: 'Modalità',
      value: 'Pacchetto',
      tone: HomeFigureTone.pending,
    );
  }

  if (figures.isHourly)
  {
    return const HomeFigure(label: 'Modalità', value: 'A ore');
  }

  if (figures.isMonthly)
  {
    return const HomeFigure(label: 'Modalità', value: 'Mensile');
  }

  return const HomeFigure(label: 'Modalità', value: '—', tone: HomeFigureTone.absent);
}

// withTariff is for whoever answers for the pupil's hours: a parent, or a
// pupil nobody answers for.
List<HomeFigure> pupilFigures(PupilMonthFiguresItem figures, {required bool withTariff})
{
  return [
    HomeFigure(
      label: 'Presenze',
      value: '${figures.totalPresences}',
      unit: _days(figures.totalPresences),
    ),
    // Looking ahead where the presences look back: the rest of the month.
    HomeFigure(
      label: 'Prenotate',
      value: '${figures.bookedPresences}',
      unit: _days(figures.bookedPresences),
    ),
    HomeFigure(
      label: 'Lezioni',
      value: _hours(figures.lessonMinutes),
      unit: _hoursUnit(figures.lessonMinutes / 60),
    ),
    if (withTariff) _tariffFigure(figures),
  ];
}

// Type grows with the room a tile has: two to a row the figures are
// written large, three smaller, four smaller still and closer together, so
// that at half a page "€ 187,50" and "0.5 giorni" stand whole.
class _TileScale
{
  static const double label = 11;
  static const double lineHeight = 1.3;
  static const double border = 1.5;

  static const double labelGap = 10;
  static const double warningGap = 8;

  final double value;
  final double unit;
  final double warning;

  // Vertical and horizontal padding, and the gap between tiles.
  final double padding;
  final double side;
  final double gap;

  const _TileScale({
    required this.value,
    required this.unit,
    required this.warning,
    required this.padding,
    required this.side,
    required this.gap,
  });

  static const _TileScale _wide =
      _TileScale(value: 34, unit: 17, warning: 14.5, padding: 18, side: 16, gap: 14);
  static const _TileScale _narrow =
      _TileScale(value: 28, unit: 14.5, warning: 13.5, padding: 14, side: 16, gap: 14);
  static const _TileScale _quad =
      _TileScale(value: 24, unit: 13, warning: 12.5, padding: 12, side: 12, gap: 10);

  static _TileScale of(int columns)
  {
    if (columns >= 4)
    {
      return _quad;
    }

    return columns <= 2 ? _wide : _narrow;
  }

  // Every line is kept single, so a tile's height follows from the scale.
  // Warnings are a teacher's alone, and a teacher's card never scrolls.
  double get tileHeight => 2 * (padding + border) + label * lineHeight + labelGap + value;
}

class HomeMonthSection extends StatelessWidget
{
  // Minimum widths for four and three figures per row. Four tiles of the
  // quad scale need 125 each for "€ 187,50" to stand unshrunk; half a page
  // at the widest gives 553 inside the card.
  static const double _fourInARowFrom = 530;
  static const double _threeInARowFrom = 380;

  static const double _nameSize = 16;
  static const double _nameGap = 10;
  static const double _groupGap = 22;

  // Past two people the card stops growing and scrolls, the third's name
  // just showing under the fold.
  static const int _scrollPast = 2;
  static const double _peek = 26;

  // Every figure of a person on one row where the card is wide enough; no
  // tile is left without a neighbour otherwise: four go two by two rather
  // than three and one.
  static int columnsFor({required double width, required List<HomeFigureGroup> groups})
  {
    final int most = width >= _fourInARowFrom
        ? 4
        : width >= _threeInARowFrom
            ? 3
            : 2;

    if (groups.isEmpty)
    {
      return 2;
    }

    final int figures = groups.map((group) => group.figures.length).reduce(math.max);

    if (figures == 4 && most == 3)
    {
      return 2;
    }

    return math.min(figures, most);
  }

  // Null when the month could not be read; empty when there is nobody to
  // sum up, as for a parent with no child linked.
  final List<HomeFigureGroup>? groups;

  final bool isLoading;

  final String title;

  // Set by the page: a LayoutBuilder here cannot report a height inside a
  // row of equal-height cards.
  final int columns;

  const HomeMonthSection({
    super.key,
    required this.groups,
    required this.title,
    this.isLoading = false,
    this.columns = 2,
  });

  // As tall as its content and no taller: the card under it takes the rest
  // of the column.
  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      eyebrow: 'Questo mese',
      title: title,
      child: _buildBody(),
    );
  }

  Widget _buildBody()
  {
    if (isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
        ),
      );
    }

    final List<HomeFigureGroup>? read = groups;

    if (read == null || read.isEmpty)
    {
      return Text(
        read == null
            ? 'Il riepilogo del mese non è disponibile.'
            : 'Nessuno studente associato.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    final _TileScale scale = _TileScale.of(columns);

    final Widget people = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < read.length; i++) ...[
          if (i > 0) const SizedBox(height: _groupGap),
          if (read[i].name.isNotEmpty) ...[
            Text(
              read[i].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: _nameSize,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppTheme.trialTealDeep,
              ),
            ),
            const SizedBox(height: _nameGap),
          ],
          _grid(read[i].figures, scale),
        ],
      ],
    );

    if (read.length > _scrollPast)
    {
      final double group = _nameSize * 1.25 + _nameGap + scale.tileHeight;
      final double fold = _scrollPast * group + (_scrollPast - 1) * _groupGap + _peek;

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: fold),
        child: _PeopleScroll(child: people),
      );
    }

    return people;
  }

  // A partial last row keeps normal-width tiles rather than stretching them.
  // Where one figure of a row carries a warning its neighbours keep the line
  // for it, so labels and figures sit level; a row without one stays short.
  Widget _grid(List<HomeFigure> figures, _TileScale scale)
  {
    final List<Widget> rows = [];

    for (var start = 0; start < figures.length; start += columns)
    {
      final List<HomeFigure> row = figures.sublist(
        start,
        (start + columns).clamp(0, figures.length),
      );
      final bool aside = row.any((figure) => figure.hasAside);

      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) SizedBox(width: scale.gap),
              Expanded(
                child: i < row.length
                    ? _FigureTile(figure: row[i], scale: scale, keepsAsideLine: aside)
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: scale.gap),
          rows[i],
        ],
      ],
    );
  }
}

// Owns the controller the always-visible scrollbar needs.
class _PeopleScroll extends StatefulWidget
{
  final Widget child;

  const _PeopleScroll({required this.child});

  @override
  State<_PeopleScroll> createState() => _PeopleScrollState();
}

class _PeopleScrollState extends State<_PeopleScroll>
{
  final ScrollController _controller = ScrollController();

  @override
  void dispose()
  {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.only(right: 14),
        child: widget.child,
      ),
    );
  }
}

class _FigureTile extends StatelessWidget
{
  final HomeFigure figure;
  final _TileScale scale;

  // Room for the line under the value even when this figure has none, to
  // match the row.
  final bool keepsAsideLine;

  const _FigureTile({
    required this.figure,
    required this.scale,
    required this.keepsAsideLine,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? warning = figure.warning;
    final bool warned = warning != null;

    final Color valueColor = switch (figure.tone)
    {
      HomeFigureTone.plain => AppTheme.trialOcean,
      HomeFigureTone.pending => AppTheme.trialTealDeep,
      HomeFigureTone.absent => AppTheme.trialMutedText,
    };

    // Every line stays single and shrinks before it wraps or is cut, so the
    // figures of a row sit on one line whatever their labels say.
    Widget line(Widget text) => Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(fit: BoxFit.scaleDown, child: text),
        );

    final Widget label = line(Text(
      figure.label.toUpperCase(),
      maxLines: 1,
      style: GoogleFonts.plusJakartaSans(
        fontSize: _TileScale.label,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        height: _TileScale.lineHeight,
        color: AppTheme.trialMutedText,
      ),
    ));

    // The unit follows the figure on its baseline, smaller and quieter, as
    // the mode follows the hours on the day card: "5 giorni".
    final Widget value = line(Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: figure.value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: figure.isWord ? scale.value * 0.7 : scale.value,
              fontWeight: FontWeight.w700,
              height: 1,
              color: valueColor,
            ),
          ),
          if (figure.unit.isNotEmpty)
            TextSpan(
              text: ' ${figure.unit}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: scale.unit,
                fontWeight: FontWeight.w600,
                height: 1,
                color: AppTheme.trialMutedText,
              ),
            ),
        ],
      ),
      maxLines: 1,
    ));

    // Under the value: the warning, else the move against last month. Icon
    // and text centred on one another: the text's box is exactly its type
    // size, so the middle of the box is the middle of the glyphs.
    final HomeDelta? delta = figure.delta;

    final (IconData, Color, String)? aside = warned
        ? (Icons.warning_amber_rounded, AppTheme.modifiedAccent, warning)
        : delta == null
            ? null
            : (
                delta.direction == 0
                    ? Icons.remove_rounded
                    : delta.direction > 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                delta.direction == 0
                    ? AppTheme.trialMutedText
                    : delta.direction > 0
                        ? AppTheme.trialSeaGreen
                        : AppTheme.trialDanger,
                delta.text,
              );

    final Widget asideLine = SizedBox(
      height: scale.warning + 2,
      child: aside == null
          ? null
          : line(Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(aside.$1, size: scale.warning + 2, color: aside.$2),
                const SizedBox(width: 5),
                Text(
                  aside.$3,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scale.warning,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: aside.$2,
                  ),
                ),
              ],
            )),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: scale.side, vertical: scale.padding),
      decoration: BoxDecoration(
        color: warned ? AppTheme.modifiedAccentSurface : AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: warned ? AppTheme.modifiedAccent.withValues(alpha: 0.28) : AppTheme.trialLine,
          width: _TileScale.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: _TileScale.labelGap),
          SizedBox(height: scale.value, child: value),
          if (aside != null || keepsAsideLine) ...[
            const SizedBox(height: _TileScale.warningGap),
            asideLine,
          ],
        ],
      ),
    );
  }
}
