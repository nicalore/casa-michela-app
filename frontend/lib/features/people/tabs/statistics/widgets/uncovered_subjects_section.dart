import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../../shared/widgets/scroll_edge_fade.dart';
import '../../../models/teacher_subjects_statistics_item.dart';
import 'stat_widgets.dart';

const String _title = 'Discipline senza docenti';
const String _noneLabel = 'Nessuna disciplina senza docenti.';

// A column narrower than this would cut most names.
const double _minColumnWidth = 260;
const int _maxColumns = 4;

// StatColumnDivider: 24 of padding each side of a 1 px rule.
const double _dividerWidth = 49;

// Past this many rows per column the list scrolls inside a box this high.
const int _wholeListRows = 12;
const double _scrollingHeight = 420;

// Room for the scrollbar thumb beside the last column.
const double _thumbRoom = 12;

// Down each column; a list too long to show whole runs across them and scrolls.
class UncoveredSubjectsSection extends StatefulWidget
{
  final List<SubjectDistributionItem> subjects;

  const UncoveredSubjectsSection({super.key, required this.subjects});

  @override
  State<UncoveredSubjectsSection> createState() => _UncoveredSubjectsSectionState();
}

class _UncoveredSubjectsSectionState extends State<UncoveredSubjectsSection>
{
  final ScrollController _controller = ScrollController();

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  Widget _row(SubjectDistributionItem subject, StatMetrics metrics)
  {
    final programName = subject.programName;

    return Padding(
      padding: EdgeInsets.only(bottom: metrics.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          OverflowTooltipText(
            text: subject.name,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: metrics.rowSize,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialInk,
            ),
          ),
          if (programName != null) ...[
            const SizedBox(height: 2),
            OverflowTooltipText(
              text: programName,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: metrics.badgeSize,
                fontWeight: FontWeight.w500,
                color: AppTheme.trialMutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Runs whose lengths differ by one at most, the longer ones first.
  List<List<SubjectDistributionItem>> _downColumns(int count)
  {
    final subjects = widget.subjects;
    final int base = subjects.length ~/ count;
    final int longer = subjects.length % count;
    int startOf(int column) => column * base + math.min(column, longer);

    return [
      for (var column = 0; column < count; column++)
        subjects.sublist(startOf(column), startOf(column + 1)),
    ];
  }

  List<List<SubjectDistributionItem>> _acrossColumns(int count)
  {
    final subjects = widget.subjects;

    return [
      for (var column = 0; column < count; column++)
        [for (var index = column; index < subjects.length; index += count) subjects[index]],
    ];
  }

  Widget _grid(List<List<SubjectDistributionItem>> columns, StatMetrics metrics)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, column) in columns.indexed) ...[
            if (index > 0) const StatColumnDivider(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final subject in column) _row(subject, metrics)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(double width, StatMetrics metrics)
  {
    final int fitting = ((width + _dividerWidth) / (_minColumnWidth + _dividerWidth)).floor();
    final int count = fitting.clamp(1, math.min(_maxColumns, widget.subjects.length));
    final int rows = (widget.subjects.length / count).ceil();

    if (rows <= _wholeListRows)
    {
      return _grid(_downColumns(count), metrics);
    }

    return SizedBox(
      height: _scrollingHeight,
      child: RawScrollbar(
        controller: _controller,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(10),
        thumbColor: AppTheme.trialLine,
        child: ScrollEdgeFade(
          child: SingleChildScrollView(
            controller: _controller,
            child: Padding(
              padding: const EdgeInsets.only(right: _thumbRoom),
              child: _grid(_acrossColumns(count), metrics),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final StatMetrics metrics = StatMetrics.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const StatSectionTitle(_title),
        SizedBox(height: metrics.titleGap),
        if (widget.subjects.isEmpty)
          Center(
            child: Text(
              _noneLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.trialMutedText,
              ),
            ),
          )
        else
          LayoutBuilder(builder: (context, constraints) => _list(constraints.maxWidth, metrics)),
      ],
    );
  }
}
