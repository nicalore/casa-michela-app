import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../notifications/notification_board.dart';
import '../models/person_item.dart';
import '../utils/student_notes_strings.dart';
import 'teacher_rating_dots.dart';

const double _tileGap = 12;
const double _tileRadius = 18;
const double _markGap = 14;

// Below this the pairs would wrap their lines thin: one column instead.
const double _twoColumnsWidth = 620;

const double _pointsPerCriterion = 0.5;

// "3,5", "4": the score as read aloud.
String _scoreText(double score)
{
  final String points =
      score == score.roundToDouble() ? '${score.round()}' : score.toStringAsFixed(1).replaceAll('.', ',');

  return '$points su 5';
}

const int _scoreSteps = 10;

// Below the wide window (AppPageDensity), as the other cards of the page.
const double _denseDotSize = 16;
const double _denseScoreSize = 15;

// The administrators' judgement of a teacher: a tick per criterion met, saved at each click.
class TeacherEvaluationCard extends StatefulWidget
{
  final PersonItem person;

  const TeacherEvaluationCard({super.key, required this.person});

  @override
  State<TeacherEvaluationCard> createState() => _TeacherEvaluationCardState();
}

class _TeacherEvaluationCardState extends State<TeacherEvaluationCard>
{
  late Set<String> _met = {...?widget.person.teacherCriteria};

  // Criteria whose save is under way: a second click waits for the first.
  final Set<String> _saving = {};

  // Worth nothing and closed while not collaborating; the ticks stay as they were.
  bool get _lapsed => widget.person.isActiveCollaborator != true;

  double get _score => _lapsed ? 0 : _met.length * _pointsPerCriterion;

  @override
  void didUpdateWidget(TeacherEvaluationCard oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.person, widget.person) && _saving.isEmpty)
    {
      _met = {...?widget.person.teacherCriteria};
    }
  }

  Future<void> _toggle(String key) async
  {
    if (_lapsed || _saving.contains(key))
    {
      return;
    }

    final bool met = !_met.contains(key);

    setState(()
    {
      met ? _met.add(key) : _met.remove(key);
      _saving.add(key);
    });

    try
    {
      final ({List<String> met, double rating}) saved = await ApiService().setTeacherCriterion(
        widget.person.fiscalCode,
        key,
        met: met,
      );

      // Judged: the server took the reminder to rate them away.
      NotificationBoard.instance.dropRatingReminder(widget.person.fiscalCode);

      if (mounted)
      {
        setState(() => _met = saved.met.toSet());
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => met ? _met.remove(key) : _met.add(key));
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
    finally
    {
      if (mounted)
      {
        setState(() => _saving.remove(key));
      }
    }
  }

  // As wide as the widest score, its text flush right: «3» and «3,5» leave the dots where they are.
  Widget _buildScore(BuildContext context, {required bool dense})
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: dense ? _denseScoreSize : 17,
      fontWeight: FontWeight.w800,
      color: AppTheme.trialOcean,
    );
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    double widest = 0;

    for (var step = 0; step <= _scoreSteps; step++)
    {
      // Measured as Text draws it, the theme's letter spacing included.
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: _scoreText(step * _pointsPerCriterion),
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();

      widest = widest < painter.width ? painter.width : widest;
      painter.dispose();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeacherRatingDots(value: _score, dotSize: dense ? _denseDotSize : TeacherRatingDots.defaultDotSize),
        SizedBox(width: dense ? 10 : 14),
        SizedBox(
          width: widest.ceilToDouble(),
          child: Text(_scoreText(_score), textAlign: TextAlign.right, maxLines: 1, softWrap: false, style: style),
        ),
      ],
    );
  }

  Widget _buildLapsed()
  {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.trialGoldSurface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.trialTealDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              evaluationLapsed(widget.person.firstName),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialOcean,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(TeacherCriterion criterion)
  {
    return _CriterionTile(
      criterion: criterion,
      met: _met.contains(criterion.key),
      lapsed: _lapsed,
      onTap: () => _toggle(criterion.key),
    );
  }

  // In pairs as listed, both tiles of a row as tall as the taller.
  Widget _buildCriteria()
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _twoColumnsWidth)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < kCriteria.length; i++) ...[
                if (i > 0) const SizedBox(height: _tileGap),
                _buildTile(kCriteria[i]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < kCriteria.length; i += 2) ...[
              if (i > 0) const SizedBox(height: _tileGap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildTile(kCriteria[i])),
                    const SizedBox(width: _tileGap),
                    Expanded(child: i + 1 < kCriteria.length ? _buildTile(kCriteria[i + 1]) : const SizedBox()),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // Below the wide window the card takes the page's sizes, and the score goes under the title
    // rather than squeezing it mid-word.
    final bool dense = AppPageDensity.of(context);

    return AppCard(
      title: kEvaluationTitle,
      compact: !dense,
      // Its tiles take clicks, which text selection would catch first.
      selectable: false,
      leading: AppCardBadge(icon: Icons.star_rounded, compact: !dense),
      trailing: _buildScore(context, dense: dense),
      trailingFit: dense ? AppCardTrailing.endOrBelow : AppCardTrailing.beside,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_lapsed) _buildLapsed(),
          Text(
            evaluationHint(widget.person.firstName),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 18),
          _buildCriteria(),
        ],
      ),
    );
  }
}

// A criterion's tile, ringed in gold under the pointer as the other ticked rows; still when lapsed.
class _CriterionTile extends StatefulWidget
{
  final TeacherCriterion criterion;
  final bool met;
  final bool lapsed;
  final VoidCallback onTap;

  const _CriterionTile({required this.criterion, required this.met, required this.lapsed, required this.onTap});

  @override
  State<_CriterionTile> createState() => _CriterionTileState();
}

class _CriterionTileState extends State<_CriterionTile>
{
  static const Duration _fade = Duration(milliseconds: 160);

  static const double _ringWidth = 2;

  // Opaque, so the fill's fade never passes through a darker shade.
  static final Color _restFill = Color.alphaBlend(AppTheme.trialPaper.withValues(alpha: 0.6), Colors.white);

  bool _hover = false;

  @override
  void didUpdateWidget(_CriterionTile oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.lapsed)
    {
      _hover = false;
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final TeacherCriterion criterion = widget.criterion;
    final bool lit = widget.met && !widget.lapsed;

    // The ring is always there, clear at rest: lighting it moves nothing.
    final Widget tile = AnimatedContainer(
      duration: _fade,
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14 - _ringWidth, 14 - _ringWidth, 16 - _ringWidth, 16 - _ringWidth),
      decoration: BoxDecoration(
        color: lit ? kPickedSurface : _restFill,
        borderRadius: BorderRadius.circular(_tileRadius),
        border: Border.all(
          color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
          width: _ringWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCheckMark(selected: widget.met, muted: widget.lapsed),
          const SizedBox(width: _markGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterion.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialOcean,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  criterion.other,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.lapsed)
    {
      return tile;
    }

    return Semantics(
      checked: widget.met,
      label: criterion.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: tile,
        ),
      ),
    );
  }
}
