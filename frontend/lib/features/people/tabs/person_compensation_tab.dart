import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/app_month_button.dart';
import '../../../shared/widgets/app_text_link.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/hover_gold_frame.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../accounting/accounting_page.dart';
import '../../accounting/export/accounting_pdf_export.dart';
import '../../accounting/export/teacher_compensation_pdf.dart';
import '../../accounting/models/teacher_hours_items.dart';
import '../../accounting/utils/accounting_jump.dart';
import '../../accounting/utils/accounting_strings.dart' show compensationPdfFile, compensationPdfFooter, kExportPdf;
import '../../association/tabs/opening_hours/calendar_bounds.dart';
import '../edit/person_edit_form.dart';
import '../models/compensation_items.dart';
import '../models/person_item.dart';
import '../../accounting/utils/opening_strings.dart' show openingRowLabel;
import '../../accounting/widgets/opening_pending_pill.dart';
import '../utils/compensation_strings.dart';
import '../widgets/card_eye.dart';
import '../widgets/compensation_dialog.dart';
import '../widgets/iban_dialog.dart';
import '../widgets/volunteering_dialog.dart';
import '../widgets/volunteering_pill.dart';
import '../widgets/person_detail_widgets.dart';

const double _contentWidth = 1600;

const Duration _fetchFade = Duration(milliseconds: 150);
const double _fetchingOpacity = 0.45;

// Under the first the nine columns no longer fit and the days become a list;
// under the second their names go short.
const double _tableMinWidth = 640;
const double _fullNamesMinWidth = 860;

// Under this the month and the button take a line each.
const double _oneHeaderLineMinWidth = 560;

// Under this the volunteering rule takes its own line above the button and the month.
const double _pillBesideMinWidth = 1040;
const double _densePillBesideMinWidth = 860;
const double _pillMostShare = 0.4;

const double _beforeMonthNav = 16;

const double _exportWidth = 300;

// Under this the IBAN and its two buttons take a line each.
const double _oneIbanLineMinWidth = 900;

const double _ruleWidth = 1.5;

// The pay card's first line: three sums, then the two rates a little wider.
const int _moneyShare = 4;
const int _rateShare = 5;
const int _payShares = 3 * _moneyShare + 2 * _rateShare;

// Kept between a label on one line and the next column's.
const double _labelGap = 16;

// A day's stretches stacked in a cell keep off the row's rules.
const double _stackedLinesPadding = 7;

const Color _headSurface = Color(0xFFF5F8F8);
const Color _rowRule = Color(0xFFEDF2F1);

String _missing(int? cents) => cents == null ? '—' : formatAmount(cents);

String _spanText(CompensationSpan span) => '${span.start} – ${span.end}';

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

// The same week as the row before: the rule between weeks is the stronger one.
DateTime _mondayOf(DateTime day) => startOfWeek(day);

// What a member of staff is owed month by month, and the worked days behind it.
class PersonCompensationTab extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // Opened on this month, a day's summary say; the current one otherwise.
  final DateTime? month;

  const PersonCompensationTab({super.key, required this.person, required this.onUpdate, this.month});

  @override
  State<PersonCompensationTab> createState() => _PersonCompensationTabState();
}

class _PersonCompensationTabState extends State<PersonCompensationTab>
{
  final ApiService _api = ApiService();

  final DateTime _lastMonth = _monthOf(romeNow());
  // Accounting has no time limit: back to the association's first month.
  final DateTime _firstMonth = _monthOf(kAssociationFoundedOn);

  late DateTime _month = _startMonth;
  late String? _iban = widget.person.iban;
  bool _deletingIban = false;
  bool _exporting = false;

  DateTime get _startMonth
  {
    final DateTime? asked = widget.month;

    if (asked == null)
    {
      return _lastMonth;
    }

    final DateTime month = _monthOf(asked);

    return month.isAfter(_lastMonth) ? _lastMonth : (month.isBefore(_firstMonth) ? _firstMonth : month);
  }

  CompensationMonth? _shown;

  // Why the month on show could not be read.
  Object? _failure;
  Set<DateTime> _worked = const {};

  bool _fetching = true;

  bool get _teaches => widget.person.shownRoles.any((role) => role.toUpperCase() == 'DOCENTE');

  // Only the last month asked for may land: the arrows can outrun the answers.
  int _asked = 0;

  @override
  void initState()
  {
    super.initState();

    _load();
    _loadWorkedMonths();
  }

  @override
  void didUpdateWidget(PersonCompensationTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.person.iban != widget.person.iban)
    {
      _iban = widget.person.iban;
    }
  }

  Future<void> _load() async
  {
    final int asked = ++_asked;

    try
    {
      final CompensationMonth shown = await _api.getCompensation(widget.person.fiscalCode, _month);

      if (mounted && asked == _asked)
      {
        setState(()
        {
          _shown = shown;
          _fetching = false;
          _failure = null;
        });
      }
    }
    catch (error)
    {
      if (!mounted || asked != _asked)
      {
        return;
      }

      // Better nothing than last month's money under this month's name.
      setState(()
      {
        _shown = null;
        _fetching = false;
        _failure = error;
      });
    }
  }

  // Only the picker's dots: a failure leaves it without them.
  Future<void> _loadWorkedMonths() async
  {
    try
    {
      final Set<DateTime> worked = await _api.getCompensationMonths(widget.person.fiscalCode);

      if (mounted)
      {
        setState(() => _worked = worked);
      }
    }
    catch (_)
    {
      return;
    }
  }

  void _go(DateTime month)
  {
    if (month == _month)
    {
      return;
    }

    setState(()
    {
      _month = month;
      _fetching = true;
    });
    _load();
  }

  Future<void> _edit() async
  {
    final CompensationMonth? shown = _shown;

    // While the month is changing, what is shown still belongs to the one before.
    if (shown == null || _fetching)
    {
      return;
    }

    final bool saved = await showCompensationDialog(
      context: context,
      person: widget.person,
      month: _month,
      shown: shown,
    );

    if (!saved || !mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: kCompensationSaved);
    setState(() => _fetching = true);
    _load();
    widget.onUpdate();
  }

  Future<void> _editVolunteering() async
  {
    final CompensationMonth? shown = _shown;

    if (shown == null || _fetching)
    {
      return;
    }

    final bool saved = await showVolunteeringDialog(
      context: context,
      person: widget.person,
      month: _month,
      shown: shown,
    );

    if (!saved || !mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: kVolunteeringSaved);
    setState(() => _fetching = true);
    _load();
  }

  Future<void> _editIban() async
  {
    final String? before = _iban;
    final String? saved = await showIbanDialog(context: context, person: widget.person, iban: before);

    if (saved == null || !mounted)
    {
      return;
    }

    setState(() => _iban = saved);
    CustomSnackBar.show(context: context, message: before == null ? kIbanAdded : kIbanSaved);
    widget.onUpdate();
  }

  Future<void> _deleteIban() async
  {
    if (_deletingIban || !await confirmIbanDeletion(context) || !mounted)
    {
      return;
    }

    _deletingIban = true;

    try
    {
      await _api.updateIban(widget.person.fiscalCode, null);

      if (!mounted)
      {
        return;
      }

      setState(() => _iban = null);
      CustomSnackBar.show(context: context, message: kIbanDeleted);
      widget.onUpdate();
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
    finally
    {
      _deletingIban = false;
    }
  }

  Widget _buildMonthNav(bool dense, {required bool stretched})
  {
    final double size = dense ? 38 : CarouselArrowButton.defaultSize;
    final double iconSize = dense ? 18 : CarouselArrowButton.defaultIconSize;

    final Widget label = Text(
      formatMonthYear(_month),
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13.5 : 17,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
      ),
    );

    // Grown with the text, a tenth larger below the wide window.
    final double labelWidth = MediaQuery.textScalerOf(context).scale(dense ? 130 : 190);

    return Row(
      mainAxisSize: stretched ? MainAxisSize.max : MainAxisSize.min,
      children: [
        AppMonthButton(
          selected: _month,
          first: _firstMonth,
          last: _lastMonth,
          marked: _worked,
          size: size,
          // Stretched it opens the line, at the page's left edge.
          startAligned: stretched,
          onPicked: _go,
        ),
        const SizedBox(width: 12),
        CarouselArrowButton(
          icon: Icons.chevron_left_rounded,
          size: size,
          iconSize: iconSize,
          isDisabled: _month == _firstMonth,
          onTap: () => _go(DateTime(_month.year, _month.month - 1)),
        ),
        const SizedBox(width: 8),
        if (stretched)
          Expanded(child: Center(child: label))
        else
          SizedBox(width: labelWidth, child: Center(child: label)),
        const SizedBox(width: 8),
        CarouselArrowButton(
          icon: Icons.chevron_right_rounded,
          size: size,
          iconSize: iconSize,
          isDisabled: _month == _lastMonth,
          onTap: () => _go(DateTime(_month.year, _month.month + 1)),
        ),
      ],
    );
  }

  // Only a paid teacher owes the unpaid hour.
  Widget? _buildPill(bool dense)
  {
    final CompensationMonth? shown = _shown;

    if (shown == null || !shown.isPaid || !_teaches)
    {
      return null;
    }

    return AnimatedOpacity(
      duration: _fetchFade,
      opacity: _fetching ? _fetchingOpacity : 1,
      child: VolunteeringPill(
        rule: shown.volunteering,
        monthOnly: shown.volunteeringMonthOnly ? _month : null,
        dense: dense,
        onTap: _editVolunteering,
      ),
    );
  }

  Widget _buildHeader(double width, bool dense, _Metrics metrics)
  {
    final Widget? button = _shown?.canEdit == true
        ? tabActionButton(
            label: kEditCompensationLabel,
            icon: Icons.edit_rounded,
            width: metrics.actionWidth(context),
            onPressed: _edit,
          )
        : null;
    final Widget? pill = _buildPill(dense);

    if (width < _oneHeaderLineMinWidth)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthNav(dense, stretched: true),
          if (pill != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: pill),
          ],
          if (button != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: button),
          ],
        ],
      );
    }

    final Widget actions = Row(
      children: [
        const Spacer(),
        if (button != null) ...[button, const SizedBox(width: _beforeMonthNav)],
        _buildMonthNav(dense, stretched: false),
      ],
    );

    if (pill == null)
    {
      return actions;
    }

    final double beside = MediaQuery.textScalerOf(context).scale(dense ? _densePillBesideMinWidth : _pillBesideMinWidth);

    if (width < beside)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: pill),
          const SizedBox(height: 10),
          actions,
        ],
      );
    }

    // Bounded, so a long month note shortens instead of pushing the month away.
    return Row(
      children: [
        ConstrainedBox(constraints: BoxConstraints(maxWidth: width * _pillMostShare), child: pill),
        const SizedBox(width: _beforeMonthNav),
        Expanded(child: actions),
      ],
    );
  }

  Widget _buildMonth(CompensationMonth shown, _Metrics metrics, double gap)
  {
    if (shown.days.isEmpty && shown.openingGross == null && !shown.openingPending)
    {
      // Only teaching leaves hours here: for the others a month is what they were in it.
      return _teaches
          ? Center(child: AppEmptyCard(icon: Icons.event_busy_rounded, message: noHoursMessage(_month)))
          : _CollaborationCard(shown: shown, metrics: metrics);
    }

    return _buildDays(shown, metrics, gap);
  }

  // The teachers' summary of that day, on the band its first hours fall in.
  void _openDay(CompensationDay day)
  {
    final List<CompensationSpan> worked = day.worked;
    final TimeBucket? first = worked.isEmpty
        ? null
        : bucketFor(timeOfDayFromMinutes(minutesOfClock(worked.first.start)));
    final TimeBucket band = first ?? TimeBucket.afternoon;

    AccountingJumps.teacherHours.request(day.date, band);
    context.go(kAccountingRoute);
  }

  Future<void> _exportPdf(CompensationMonth shown) async
  {
    // While another month loads the days shown are still the month before's.
    if (_exporting || _fetching)
    {
      return;
    }

    final String name = '${widget.person.firstName} ${widget.person.lastName}';
    final DateTime month = _month;

    setState(() => _exporting = true);

    await exportAccountingPdf(
      context,
      title: compensationPdfFooter(name, month),
      fileName: compensationPdfFile(name, month),
      bytes: () => buildTeacherCompensationPdf(name: name, month: month, shown: shown),
    );

    if (mounted)
    {
      setState(() => _exporting = false);
    }
  }

  Widget _buildDays(CompensationMonth shown, _Metrics metrics, double gap)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown.openingPending) ...[
          const Align(alignment: Alignment.centerLeft, child: OpeningPendingPill(fontSize: 14)),
          SizedBox(height: gap / 2),
        ],
        if (shown.isPaid)
          _PayCard(shown: shown, metrics: metrics)
        else
          _CollaborationCard(shown: shown, metrics: metrics),
        SizedBox(height: gap),
        if (metrics.isList)
          _DayList(shown: shown, metrics: metrics, onOpenDay: _openDay)
        else
          _DayTable(shown: shown, metrics: metrics, onOpenDay: _openDay),
        SizedBox(height: gap),
        Center(
          child: AppGradientButton(
            label: kExportPdf,
            icon: Icons.picture_as_pdf_outlined,
            width: _exportWidth,
            height: 50,
            fontSize: 14,
            busy: _exporting,
            onPressed: () => unawaited(_exportPdf(shown)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final CompensationMonth? shown = _shown;
    final bool dense = AppBreakpoints.of(context).isDense;
    final double gap = personCardGap(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth.clamp(0, _contentWidth);
        final _Metrics metrics = _Metrics.of(width, dense);

        return ScrollEdgeFade(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: pageTransitionBlocks([
                    _IbanCard(iban: _iban, metrics: metrics, onEdit: _editIban, onDelete: _deleteIban),
                    SizedBox(height: gap),
                    _buildHeader(width, dense, metrics),
                    SizedBox(height: gap),
                    if (shown == null && _fetching)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
                      )
                    else if (shown == null && _failure != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: AppLoadFailedRoom(
                          error: _failure,
                          message: readableApiError(_failure!),
                          onRetry: _load,
                        ),
                      )
                    else if (shown != null)
                      AnimatedOpacity(
                        duration: _fetchFade,
                        opacity: _fetching ? _fetchingOpacity : 1,
                        child: _buildMonth(shown, metrics, gap),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Every size that steps down with the window, in one place.
class _Metrics
{
  final bool isList;
  final bool shortNames;
  final bool oneIbanLine;

  final double radius;
  final EdgeInsets cardPadding;
  final EdgeInsets ibanPadding;
  final double ibanLine;

  // The longest label's room, so the page's buttons all come out alike.
  final double actionRoom;

  final double payText;
  final double payLine;
  final double rateText;
  final double totalsText;
  final double labelText;
  final double figureRulePadding;
  final double totalsGap;
  final double badge;

  final double cell;
  final double columnHead;
  final double groupHead;
  final double rowHeight;
  final double sidePadding;

  const _Metrics({
    required this.isList,
    required this.shortNames,
    required this.oneIbanLine,
    required this.radius,
    required this.cardPadding,
    required this.ibanPadding,
    required this.ibanLine,
    required this.actionRoom,
    required this.payText,
    required this.payLine,
    required this.rateText,
    required this.totalsText,
    required this.labelText,
    required this.figureRulePadding,
    required this.totalsGap,
    required this.badge,
    required this.cell,
    required this.columnHead,
    required this.groupHead,
    required this.rowHeight,
    required this.sidePadding,
  });

  double actionWidth(BuildContext context) => MediaQuery.textScalerOf(context).scale(actionRoom);

  factory _Metrics.of(double width, bool dense)
  {
    final bool shortNames = width < _fullNamesMinWidth;
    final bool oneIbanLine = width >= _oneIbanLineMinWidth;

    if (!dense)
    {
      return _Metrics(
        isList: false,
        shortNames: shortNames,
        oneIbanLine: oneIbanLine,
        radius: 32,
        cardPadding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
        ibanPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        ibanLine: 30,
        actionRoom: 270,
        payText: 34,
        payLine: 44,
        rateText: 27,
        totalsText: 22,
        labelText: 12,
        figureRulePadding: 32,
        totalsGap: 16,
        badge: 60,
        cell: 15.5,
        columnHead: 13,
        groupHead: 12,
        rowHeight: 48,
        sidePadding: 30,
      );
    }

    return _Metrics(
      isList: width < _tableMinWidth,
      shortNames: shortNames,
      oneIbanLine: oneIbanLine,
      radius: 24,
      cardPadding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      ibanPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ibanLine: 24,
      actionRoom: 214,
      payText: shortNames ? 20 : 23,
      payLine: 32,
      rateText: shortNames ? 16 : 18,
      totalsText: shortNames ? 14 : 16.5,
      labelText: 10,
      figureRulePadding: shortNames ? 16 : 24,
      totalsGap: 10,
      badge: 46,
      cell: shortNames ? 12 : 13.5,
      columnHead: shortNames ? 11 : 11.5,
      groupHead: 10,
      rowHeight: shortNames ? 38 : 40,
      sidePadding: shortNames ? 14 : 20,
    );
  }
}

class _Card extends StatelessWidget
{
  final _Metrics metrics;
  final EdgeInsets? padding;
  final Widget child;

  const _Card({required this.metrics, required this.child, this.padding});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(metrics.radius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

// The same whichever month is shown, so it stands above them.
class _IbanCard extends StatelessWidget
{
  final String? iban;
  final _Metrics metrics;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IbanCard({required this.iban, required this.metrics, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context)
  {
    final _Metrics m = metrics;
    final String? iban = this.iban;

    final double buttonWidth = m.actionWidth(context);

    final Widget edit = tabActionButton(
      label: iban == null ? kAddIbanLabel : kEditIbanLabel,
      icon: iban == null ? Icons.add_rounded : Icons.edit_rounded,
      width: buttonWidth,
      onPressed: onEdit,
    );

    // Two side by side would not fit the narrowest window: the bin goes without its name.
    final Widget buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iban != null) ...[
          tabActionButton(
            label: kDeleteIbanLabel,
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            width: m.isList ? null : buttonWidth,
            iconOnlyTooltip: m.isList ? kDeleteIbanLabel : null,
            onPressed: onDelete,
          ),
          const SizedBox(width: 10),
        ],
        if (m.isList) Flexible(child: edit) else edit,
      ],
    );

    return EyeMasked(
      builder: (context, hidden, eye)
      {
        final Widget value = Row(
          children: [
            Expanded(
              child: _Figure(
                label: kIbanLabel,
                value: iban == null ? '—' : (hidden ? iban.replaceAll(RegExp(r'.'), '•') : iban),
                size: m.totalsText,
                line: m.ibanLine,
                labelSize: m.labelText,
                weight: FontWeight.w700,
              ),
            ),
            if (iban != null) eye,
          ],
        );

        return _Card(
          metrics: m,
          padding: m.ibanPadding,
          child: m.oneIbanLine || (iban == null && !m.isList)
              ? Row(
                  children: [
                    Expanded(child: value),
                    const SizedBox(width: 16),
                    buttons,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    value,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: buttons),
                  ],
                ),
        );
      },
    );
  }
}

// A figure's label as _Figure sets it, on one line.
double _labelWidth(BuildContext context, String label, double size)
{
  final painter = TextPainter(
    text: TextSpan(
      text: label.toUpperCase(),
      style: PageHeading.style().copyWith(fontSize: size, letterSpacing: 1.4),
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();

  return painter.width;
}

class _Figure extends StatelessWidget
{
  final String label;
  final String value;
  final double size;
  final double line;
  final double labelSize;
  final FontWeight weight;
  final Color color;

  const _Figure({
    required this.label,
    required this.value,
    required this.size,
    required this.line,
    required this.labelSize,
    this.weight = FontWeight.w800,
    this.color = AppTheme.trialOcean,
  });

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: PageHeading.style().copyWith(fontSize: labelSize, letterSpacing: 1.4),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(line),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: size,
                fontWeight: weight,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Equal columns in two groups, the second from `split` on, set apart by a rule when asked;
// too narrow, each group takes a line of its own.
class _FigureColumns extends StatelessWidget
{
  final List<Widget> cells;
  final int split;
  final _Metrics metrics;
  final bool rule;

  // Each column's share of the line; equal when not given.
  final List<int>? flexes;

  const _FigureColumns({
    required this.cells,
    required this.split,
    required this.metrics,
    this.rule = false,
    this.flexes,
  });

  Widget _line(List<Widget> cells)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, cell) in cells.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(child: cell),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (metrics.isList)
    {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(cells.sublist(0, split)),
          const SizedBox(height: 10),
          _line(cells.sublist(split)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, cell) in cells.indexed)
          Expanded(
            flex: flexes?[index] ?? 1,
            child: index == split && rule
                ? Container(
                    padding: EdgeInsets.only(left: metrics.figureRulePadding),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: AppTheme.trialLine, width: _ruleWidth)),
                    ),
                    child: cell,
                  )
                : cell,
          ),
      ],
    );
  }
}

class _Total extends StatelessWidget
{
  final String value;
  final String text;
  final double size;

  const _Total({required this.value, required this.text, required this.size});

  @override
  Widget build(BuildContext context)
  {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.plusJakartaSans(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: AppTheme.trialOcean,
              ),
            ),
            TextSpan(text: ' $text'),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

class _PayCard extends StatelessWidget
{
  final CompensationMonth shown;
  final _Metrics metrics;

  const _PayCard({required this.shown, required this.metrics});

  @override
  Widget build(BuildContext context)
  {
    final _Metrics m = metrics;

    Widget pay(String label, String value, Color color) => _Figure(
          label: label,
          value: value,
          size: m.payText,
          line: m.payLine,
          labelSize: m.labelText,
          color: color,
        );

    return _Card(
      metrics: m,
      padding: m.cardPadding,
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          // Both rates on two lines or neither, as their column allows the longer label.
          final double rateRoom = m.isList
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth * _rateShare / _payShares - m.figureRulePadding;
          final bool split = [kGrossRateLabel, kNetRateLabel].any(
            (label) => _labelWidth(context, label, m.labelText) + _labelGap > rateRoom,
          );

          Widget rate(String label, String value, Color color) => _Figure(
                label: split ? label.replaceFirst(' orario ', ' orario\n') : label,
                value: value,
                size: m.rateText,
                line: m.payLine,
                labelSize: m.labelText,
                weight: FontWeight.w700,
                color: color,
              );

          return _payLines(m, pay, rate);
        },
      ),
    );
  }

  Widget _payLines(
    _Metrics m,
    Widget Function(String label, String value, Color color) pay,
    Widget Function(String label, String value, Color color) rate,
  )
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FigureColumns(
          metrics: m,
          split: 3,
          rule: true,
          flexes: const [_moneyShare, _moneyShare, _moneyShare, _rateShare, _rateShare],
          cells: [
            pay(kGrossPayLabel, _missing(shown.gross), AppTheme.trialOcean),
            pay(kWithholdingLabel, _missing(withholdingOf(shown.gross, shown.net)), AppTheme.trialOcean),
            pay(kNetPayLabel, _missing(shown.net), AppTheme.trialTealDeep),
            rate(kGrossRateLabel, _missing(shown.grossRate), AppTheme.trialOcean),
            rate(kNetRateLabel, _missing(shown.netRate), AppTheme.trialTealDeep),
          ],
        ),
        SizedBox(height: m.totalsGap),
        const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
        SizedBox(height: m.totalsGap),
        _FigureColumns(
          metrics: m,
          split: 2,
          cells: [
            _Total(
              value: '${shown.days.length}',
              text: workedDaysText(shown.days.length),
              size: m.totalsText,
            ),
            _Total(
              value: formatMinutes(shown.workedMinutes),
              text: workedHoursText(shown.workedMinutes),
              size: m.totalsText,
            ),
            _Total(
              value: formatMinutes(shown.volunteerMinutes),
              text: kVolunteerHoursText,
              size: m.totalsText,
            ),
            _Total(
              value: formatMinutes(shown.paidMinutes),
              text: paidHoursText(shown.paidMinutes),
              size: m.totalsText,
            ),
          ],
        ),
      ],
    );
  }
}

const Map<String, IconData> _collaborationIcons = {
  'VOLUNTEER': Icons.volunteer_activism_rounded,
  'PCTO': Icons.school_rounded,
  'UNPAID': Icons.money_off_rounded,
};

// A month with nothing to pay says what the teacher was instead.
class _CollaborationCard extends StatelessWidget
{
  final CompensationMonth shown;
  final _Metrics metrics;

  const _CollaborationCard({required this.shown, required this.metrics});

  @override
  Widget build(BuildContext context)
  {
    final _Metrics m = metrics;

    final Widget kind = Row(
      children: [
        Container(
          width: m.badge,
          height: m.badge,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.brandGradient),
          child: Icon(
            _collaborationIcons[shown.collaborationType] ?? Icons.handshake_rounded,
            size: m.badge * 0.45,
            color: Colors.white,
          ),
        ),
        SizedBox(width: m.badge / 3.5),
        Expanded(
          child: _Figure(
            label: kCollaborationLabel,
            value: labelForServerValue(kCollaborationTypes, shown.collaborationType) ?? shown.collaborationType,
            size: m.payText,
            line: m.payLine,
            labelSize: m.labelText,
          ),
        ),
      ],
    );

    Widget figure(String label, String value, Color color) => _Figure(
          label: m.shortNames ? label.replaceFirst(' orario ', ' orario\n') : label,
          value: value,
          size: m.rateText,
          line: m.payLine,
          labelSize: m.labelText,
          weight: FontWeight.w700,
          color: color,
        );

    final List<Widget> figures = shown.days.isNotEmpty
        ? [
            figure(kWorkedDaysLabel, '${shown.days.length}', AppTheme.trialOcean),
            figure(kWorkedHoursLabel, formatMinutes(shown.workedMinutes), AppTheme.trialOcean),
          ]
        : [
            if (shown.isPaid) ...[
              figure(kGrossRateLabel, _missing(shown.grossRate), AppTheme.trialOcean),
              figure(kNetRateLabel, _missing(shown.netRate), AppTheme.trialTealDeep),
            ],
          ];

    if (figures.isEmpty)
    {
      return _Card(metrics: m, padding: m.cardPadding, child: kind);
    }

    if (m.isList)
    {
      return _Card(
        metrics: m,
        padding: m.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            kind,
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: figures[0]),
                const SizedBox(width: 10),
                Expanded(child: figures[1]),
              ],
            ),
          ],
        ),
      );
    }

    return _Card(
      metrics: m,
      padding: m.cardPadding,
      child: Row(
        children: [
          Expanded(flex: 2, child: kind),
          Expanded(
            child: Container(
              padding: EdgeInsets.only(left: m.figureRulePadding),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppTheme.trialLine, width: _ruleWidth)),
              ),
              child: figures[0],
            ),
          ),
          Expanded(child: figures[1]),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget
{
  const _Rule();

  @override
  Widget build(BuildContext context) => const ColoredBox(color: AppTheme.closedLine, child: SizedBox(width: _ruleWidth));
}

// Shares of the width: the columns of a group are equal, so its title sits over their middle.
class _Columns
{
  final int day;
  final int time;
  final int money;

  const _Columns({required this.day, required this.time, required this.money});

  static const _Columns full = _Columns(day: 200, time: 90, money: 112);
  static const _Columns short = _Columns(day: 130, time: 94, money: 120);
}

class _DayTable extends StatelessWidget
{
  final CompensationMonth shown;
  final _Metrics metrics;
  final ValueChanged<CompensationDay> onOpenDay;

  const _DayTable({required this.shown, required this.metrics, required this.onOpenDay});

  _Columns get _columns => metrics.shortNames ? _Columns.short : _Columns.full;

  TextStyle _cellStyle({bool strong = false}) => GoogleFonts.plusJakartaSans(
        fontSize: metrics.cell,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
        height: 1.45,
        color: strong ? AppTheme.trialOcean : AppTheme.trialInk,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  TextStyle get _dashStyle => _cellStyle().copyWith(color: const Color(0xFFA9B7BF));

  Widget _centred(int flex, Widget child)
  {
    return Expanded(
      flex: flex,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }

  Widget _dayCell(Widget child)
  {
    return Expanded(
      flex: _columns.day,
      child: Padding(
        padding: EdgeInsets.only(left: metrics.sidePadding, right: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }

  Widget _lines(Iterable<String> texts, {bool strong = false})
  {
    final List<String> lines = texts.toList();

    if (lines.isEmpty)
    {
      return Text('—', style: _dashStyle);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: lines.length > 1 ? _stackedLinesPadding : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final line in lines) Text(line, style: _cellStyle(strong: strong))],
      ),
    );
  }

  Widget _heads(List<String> labels, int flex)
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: metrics.columnHead,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final label in labels) _centred(flex, Text(label, style: style))],
    );
  }

  Widget _groupTitle(String title, int flex)
  {
    return _centred(
      flex,
      Text(
        title.toUpperCase(),
        style: PageHeading.style().copyWith(fontSize: metrics.groupHead),
      ),
    );
  }

  Widget _buildHead()
  {
    final _Columns c = _columns;
    final double groupHeight = metrics.rowHeight * 0.72;
    final double columnHeight = metrics.rowHeight * 0.66;
    final TextStyle dayStyle = GoogleFonts.plusJakartaSans(
      fontSize: metrics.columnHead,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    return Container(
      decoration: const BoxDecoration(
        color: _headSurface,
        border: Border(bottom: BorderSide(color: AppTheme.trialLine)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dayCell(
              Padding(
                padding: EdgeInsets.only(top: groupHeight),
                child: Text(kDayColumn, style: dayStyle),
              ),
            ),
            const _Rule(),
            for (final (title, labels, flex, last) in [
              (kWorkGroup, const [kStartColumn, kEndColumn, kHoursColumn], c.time, false),
              (kVolunteerGroup, const [kStartColumn, kEndColumn, kHoursColumn], c.time, false),
              (kPayGroup, const [kGrossColumn, kWithholdingColumn, kNetColumn], c.money, true),
            ]) ...[
              Expanded(
                flex: flex * labels.length,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: groupHeight,
                      child: Row(children: [_groupTitle(title, 1)]),
                    ),
                    SizedBox(height: columnHeight, child: _heads(labels, 1)),
                  ],
                ),
              ),
              if (!last) const _Rule(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(CompensationDay day, CompensationDay? before)
  {
    final _Columns c = _columns;
    final bool newWeek = before != null && _mondayOf(before.date) != _mondayOf(day.date);

    final String weekday = weekdayFullName(day.date.weekday);
    final String name = metrics.shortNames ? weekdayShortName(day.date.weekday) : weekday;

    return Container(
      constraints: BoxConstraints(minHeight: metrics.rowHeight),
      decoration: BoxDecoration(
        border: before == null
            ? null
            : Border(
                top: BorderSide(
                  color: newWeek ? AppTheme.closedLine : _rowRule,
                  width: newWeek ? _ruleWidth : 1,
                ),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dayCell(AppTextLink(text: '$name ${day.date.day}', style: _cellStyle(strong: true), onTap: () => onOpenDay(day))),
            const _Rule(),
            _centred(c.time, _lines(day.worked.map((span) => span.start))),
            _centred(c.time, _lines(day.worked.map((span) => span.end))),
            _centred(c.time, Text(formatMinutes(day.workedMinutes), style: _cellStyle(strong: true))),
            const _Rule(),
            _centred(c.time, _lines(day.volunteer.map((span) => span.start), strong: true)),
            _centred(c.time, _lines(day.volunteer.map((span) => span.end), strong: true)),
            _centred(
              c.time,
              day.volunteerMinutes == 0
                  ? Text('—', style: _dashStyle)
                  : Text(formatMinutes(day.volunteerMinutes), style: _cellStyle(strong: true)),
            ),
            const _Rule(),
            _centred(c.money, _money(day.gross, strong: true)),
            _centred(c.money, _money(withholdingOf(day.gross, day.net))),
            _centred(c.money, _money(day.net)),
          ],
        ),
      ),
    );
  }

  Widget _money(int? cents, {bool strong = false})
  {
    return cents == null
        ? Text('—', style: _dashStyle)
        : Text(formatAmount(cents), style: _cellStyle(strong: strong));
  }

  // The pay the initial set-up gave for the days before the app's accounts, above them.
  Widget _buildOpeningRow(DateTime lastDay, int gross, int? net)
  {
    final _Columns c = _columns;
    final Widget dash = Text('—', style: _dashStyle);

    return Container(
      constraints: BoxConstraints(minHeight: metrics.rowHeight),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dayCell(Text(openingRowLabel(lastDay), style: _cellStyle(strong: true))),
            const _Rule(),
            _centred(c.time, dash),
            _centred(c.time, dash),
            _centred(c.time, dash),
            const _Rule(),
            _centred(c.time, dash),
            _centred(c.time, dash),
            _centred(c.time, dash),
            const _Rule(),
            _centred(c.money, _money(gross, strong: true)),
            _centred(c.money, _money(withholdingOf(gross, net))),
            _centred(c.money, _money(net)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlainHead()
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: metrics.columnHead,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    return Container(
      constraints: BoxConstraints(minHeight: metrics.rowHeight * 0.72),
      decoration: const BoxDecoration(
        color: _headSurface,
        border: Border(bottom: BorderSide(color: AppTheme.trialLine)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dayCell(Text(kDayColumn, style: style)),
            const _Rule(),
            _centred(_plainTime, Text(kStartColumn, style: style)),
            _centred(_plainTime, Text(kEndColumn, style: style)),
            _centred(_plainTime, Text(kHoursColumn, style: style)),
          ],
        ),
      ),
    );
  }

  // As wide as three of a paid month's groups share the rest.
  int get _plainTime => 3 * _columns.time;

  Widget _buildPlainRow(CompensationDay day, CompensationDay? before)
  {
    final bool newWeek = before != null && _mondayOf(before.date) != _mondayOf(day.date);
    final String weekday = metrics.shortNames ? weekdayShortName(day.date.weekday) : weekdayFullName(day.date.weekday);

    return Container(
      constraints: BoxConstraints(minHeight: metrics.rowHeight),
      decoration: BoxDecoration(
        border: before == null
            ? null
            : Border(
                top: BorderSide(
                  color: newWeek ? AppTheme.closedLine : _rowRule,
                  width: newWeek ? _ruleWidth : 1,
                ),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dayCell(AppTextLink(text: '$weekday ${day.date.day}', style: _cellStyle(strong: true), onTap: () => onOpenDay(day))),
            const _Rule(),
            _centred(_plainTime, _lines(day.worked.map((span) => span.start))),
            _centred(_plainTime, _lines(day.worked.map((span) => span.end))),
            _centred(_plainTime, Text(formatMinutes(day.workedMinutes), style: _cellStyle(strong: true))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<CompensationDay> days = shown.days;
    final bool paid = shown.isPaid;
    final int? opening = shown.openingGross;
    final DateTime? openingDay = shown.openingDay;

    return _Card(
      metrics: metrics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (paid) _buildHead() else _buildPlainHead(),
          if (paid && opening != null && openingDay != null)
            HoverGoldFrame(
              cardRadius: metrics.radius,
              atBottom: days.isEmpty,
              child: _buildOpeningRow(openingDay, opening, shown.openingNet),
            ),
          for (var index = 0; index < days.length; index++)
            HoverGoldFrame(
              cardRadius: metrics.radius,
              atBottom: index == days.length - 1,
              child: paid
                  ? _buildRow(days[index], index == 0 ? (opening != null ? days[index] : null) : days[index - 1])
                  : _buildPlainRow(days[index], index == 0 ? null : days[index - 1]),
            ),
        ],
      ),
    );
  }
}

// Too narrow for the columns: a day per block.
class _DayList extends StatelessWidget
{
  final CompensationMonth shown;
  final _Metrics metrics;
  final ValueChanged<CompensationDay> onOpenDay;

  const _DayList({required this.shown, required this.metrics, required this.onOpenDay});

  Widget _line(String start, String? end, {required double size, required bool strong, VoidCallback? onTap})
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
      color: strong ? AppTheme.trialOcean : AppTheme.trialMutedText,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: onTap == null
              ? Text(start, style: style)
              : Align(alignment: Alignment.centerLeft, child: AppTextLink(text: start, style: style, onTap: onTap)),
        ),
        if (end != null) ...[const SizedBox(width: 10), Text(end, style: style)],
      ],
    );
  }

  Widget _buildDay(CompensationDay day)
  {
    final String times = [
      ...day.worked.map(_spanText),
      formatMinutes(day.workedMinutes),
    ].join(' · ');

    final int? gross = day.gross;
    final int? withholding = withholdingOf(day.gross, day.net);
    final int? net = day.net;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(
            '${weekdayFullName(day.date.weekday)} ${day.date.day}',
            gross == null ? null : formatAmount(gross),
            size: 13,
            strong: true,
            onTap: () => onOpenDay(day),
          ),
          const SizedBox(height: 3),
          // The withholding under the gross, taken off, and the net under it.
          _line(times, withholding == null ? null : '\u2212 ${formatAmount(withholding)}', size: 11.5, strong: false),
          if (net != null) ...[
            const SizedBox(height: 3),
            _line('', formatAmount(net), size: 11.5, strong: false),
          ],
          if (day.volunteer.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: _headSurface, borderRadius: BorderRadius.circular(10)),
              child: _line(
                '$kVolunteerGroup ${day.volunteer.map(_spanText).join(' · ')}',
                formatMinutes(day.volunteerMinutes),
                size: 11.5,
                strong: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // The initial set-up's pay of the days before the app's accounts, first.
  Widget _buildOpening(DateTime lastDay, int gross, int? net)
  {
    final int? withholding = withholdingOf(gross, net);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(openingRowLabel(lastDay), formatAmount(gross), size: 13, strong: true),
          const SizedBox(height: 3),
          _line('', withholding == null ? null : '\u2212 ${formatAmount(withholding)}', size: 11.5, strong: false),
          if (net != null) ...[
            const SizedBox(height: 3),
            _line('', formatAmount(net), size: 11.5, strong: false),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final int? opening = shown.isPaid ? shown.openingGross : null;
    final DateTime? openingDay = shown.openingDay;
    final bool first = opening != null && openingDay != null;

    return _Card(
      metrics: metrics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (first)
            HoverGoldFrame(
              cardRadius: metrics.radius,
              atTop: true,
              atBottom: shown.days.isEmpty,
              child: _buildOpening(openingDay, opening, shown.openingNet),
            ),
          for (var index = 0; index < shown.days.length; index++) ...[
            if (index > 0 || first) const Divider(height: 1, thickness: 1, color: _rowRule),
            HoverGoldFrame(
              cardRadius: metrics.radius,
              atTop: index == 0 && !first,
              atBottom: index == shown.days.length - 1,
              child: _buildDay(shown.days[index]),
            ),
          ],
        ],
      ),
    );
  }
}
