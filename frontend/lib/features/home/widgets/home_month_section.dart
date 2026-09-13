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

// One figure on the month card.
class HomeFigure
{
  final String label;
  final String value;

  // What the figure is of; replaced by the warning when there is one.
  final String note;
  final String? warning;

  final HomeFigureTone tone;

  const HomeFigure({
    required this.label,
    required this.value,
    required this.note,
    this.warning,
    this.tone = HomeFigureTone.plain,
  });

  bool get pending => tone == HomeFigureTone.pending;

  // A word rather than a number is written smaller, so it fits its slot.
  bool get isWord => value.contains(RegExp(r'[a-zA-Z]'));
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

List<HomeFigure> teacherFigures(TeacherMonthSummaryItem month)
{
  final String? rate = month.grossCompensation;
  final int? cents = rate == null ? null : parseAmountCents(rate);

  return [
    HomeFigure(
      label: 'Disponibilità',
      value: '${month.totalAvailabilities}',
      note: 'giorni da inizio mese',
      warning: month.isBelowMonthlyThreshold ? 'Meno di 9 al mese' : null,
    ),
    HomeFigure(
      label: 'Disponibilità a settimana',
      value: month.weeklyAvailabilities.toStringAsFixed(1),
      note: 'in media',
      warning: month.isBelowWeeklyThreshold ? 'Meno di 2 a settimana' : null,
    ),
    HomeFigure(
      label: 'Lezioni',
      value: _hours(month.workedMinutes),
      note: 'ore da inizio mese',
    ),
    // Only a paid collaboration has an hourly rate to multiply.
    if (cents != null)
      HomeFigure(
        label: 'Compenso lordo',
        value: formatAmount(cents),
        note: 'maturato finora',
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
      note: 'ore rimanenti in arrivo',
      tone: HomeFigureTone.pending,
    );
  }

  if (figures.isHourly)
  {
    return const HomeFigure(label: 'Modalità', value: 'A ore', note: '');
  }

  if (figures.isMonthly)
  {
    return const HomeFigure(label: 'Modalità', value: 'Mensile', note: '');
  }

  return const HomeFigure(
    label: 'Modalità',
    value: '—',
    note: 'tariffa non indicata',
    tone: HomeFigureTone.absent,
  );
}

// withTariff is for whoever answers for the pupil's hours: a parent, or a
// pupil nobody answers for.
List<HomeFigure> pupilFigures(PupilMonthFiguresItem figures, {required bool withTariff})
{
  return [
    HomeFigure(
      label: 'Presenze',
      value: '${figures.totalPresences}',
      note: 'giorni da inizio mese',
    ),
    HomeFigure(
      label: 'Lezioni',
      value: _hours(figures.lessonMinutes),
      note: 'ore da inizio mese',
    ),
    if (withTariff) _tariffFigure(figures),
  ];
}

// Type grows with the room a tile has: side by side in threes and fours the
// figures are written smaller than two to a row.
class _TileScale
{
  static const double label = 11;
  static const double lineHeight = 1.3;
  static const double border = 1.5;

  static const double labelGap = 10;
  static const double noteGap = 8;

  final double value;
  final double note;
  final double padding;

  const _TileScale({required this.value, required this.note, required this.padding});

  static const _TileScale _wide = _TileScale(value: 34, note: 14.5, padding: 18);
  static const _TileScale _narrow = _TileScale(value: 28, note: 13.5, padding: 14);

  static _TileScale of(int columns) => columns <= 2 ? _wide : _narrow;

  // Every line is kept single, so a tile's height follows from the scale.
  double get tileHeight =>
      2 * (padding + border) +
      label * lineHeight +
      labelGap +
      value +
      noteGap +
      note * lineHeight;
}

class HomeMonthSection extends StatelessWidget
{
  // Minimum widths for four and three figures per row: half a page at the
  // widest is 553 inside the card, and four must still fit there.
  static const double _fourInARowFrom = 500;
  static const double _threeInARowFrom = 380;

  static const double _nameSize = 16;
  static const double _nameGap = 10;
  static const double _groupGap = 22;

  // Past two people the card stops growing and scrolls, the third's name
  // just showing under the fold.
  static const int _scrollPast = 2;
  static const double _peek = 26;

  // No tile is left without a neighbour: three go in one row and four in
  // two, unless the card speaks for several people, whose rows all hold the
  // same figures and so line up.
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

    if (groups.length == 1 && figures == 4)
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
  Widget _grid(List<HomeFigure> figures, _TileScale scale)
  {
    final List<Widget> rows = [];

    for (var start = 0; start < figures.length; start += columns)
    {
      final List<HomeFigure> row = figures.sublist(
        start,
        (start + columns).clamp(0, figures.length),
      );

      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < columns; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                child: i < row.length
                    ? _FigureTile(figure: row[i], scale: scale)
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
          if (i > 0) const SizedBox(height: 14),
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

  const _FigureTile({required this.figure, required this.scale});

  @override
  Widget build(BuildContext context)
  {
    final String? warning = figure.warning;
    final bool warned = warning != null;

    final Color noteColor = warned ? AppTheme.modifiedAccent : AppTheme.trialMutedText;

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

    final Widget value = line(Text(
      figure.value,
      maxLines: 1,
      style: GoogleFonts.plusJakartaSans(
        fontSize: figure.isWord ? scale.value * 0.7 : scale.value,
        fontWeight: FontWeight.w700,
        height: 1,
        color: valueColor,
      ),
    ));

    final Widget note = SizedBox(
      height: scale.note * _TileScale.lineHeight,
      child: line(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warned) ...[
            Icon(Icons.warning_amber_rounded, size: scale.note + 2, color: noteColor),
            const SizedBox(width: 4),
          ],
          Text(
            warning ?? figure.note,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: scale.note,
              fontWeight: FontWeight.w600,
              height: _TileScale.lineHeight,
              color: noteColor,
            ),
          ),
        ],
      )),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: scale.padding),
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
          const SizedBox(height: _TileScale.noteGap),
          note,
        ],
      ),
    );
  }
}
