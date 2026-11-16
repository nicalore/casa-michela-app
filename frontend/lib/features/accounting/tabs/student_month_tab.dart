import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/app_month_button.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../lessons/widgets/lessons_day_bar.dart';
import '../../people/utils/payments_strings.dart' show kPaymentsSection;
import '../accounting_page.dart';
import '../export/accounting_pdf_export.dart';
import '../export/student_month_pdf.dart';
import '../models/student_month_items.dart';
import '../utils/accounting_jump.dart';
import '../utils/accounting_strings.dart';
import '../widgets/student_month_table.dart';
import '../widgets/teacher_month_table.dart' show PendingBandsNote;

const double _monthLabelWidth = 200;
const double _exportWidth = 300;
const double _denseMonthLabelWidth = 160;

// Accounting reaches back to the association's first month.
final DateTime _firstMonth = DateTime(2023, 1);

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

class StudentMonthTab extends StatefulWidget
{
  // On screen among the page's summaries: shown again, it reads the month anew.
  final bool shown;

  const StudentMonthTab({super.key, this.shown = true});

  @override
  State<StudentMonthTab> createState() => _StudentMonthTabState();
}

class _StudentMonthTabState extends State<StudentMonthTab> with DestinationRefresh
{
  // Kept while the app runs: back from a pupil's payments, the same month shows.
  static DateTime? _shownMonth;

  final ApiService _api = ApiService();

  late DateTime _thisMonth = _monthOf(romeNow());
  late DateTime _month = _shownMonth ?? _thisMonth;

  StudentMonth? _data;
  Object? _error;

  // A later answer for another month drops an earlier one.
  int _request = 0;

  bool _exporting = false;

  @override
  void initState()
  {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(StudentMonthTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.shown && !oldWidget.shown)
    {
      unawaited(_load());
    }
  }

  @override
  void onDestinationShown()
  {
    unawaited(_load());
  }

  Future<void> _load() async
  {
    final int request = ++_request;
    _thisMonth = _monthOf(romeNow());

    if (_month.isAfter(_thisMonth))
    {
      _month = _thisMonth;
    }

    try
    {
      final StudentMonth data = await _api.getStudentsMonth(_month);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _data = data;
        _error = null;
      });
    }
    catch (error)
    {
      if (!mounted || request != _request)
      {
        return;
      }

      setState(() => _error = error);
    }
  }

  void _showMonth(DateTime month)
  {
    setState(()
    {
      _month = _monthOf(month);
      _shownMonth = _month;
      _data = null;
    });

    unawaited(_load());
  }

  // Their record, on the payments; its way back leads here.
  void _openStudent(StudentMonthRow row)
  {
    context.go(
      Uri(
        path: '/people/${row.taxCode}',
        queryParameters: {'from': kAccountingRoute, 'section': kPaymentsSection},
      ).toString(),
    );
  }

  // The page turns to the pupils' daily summary of that band.
  void _openBand(PendingBand band)
  {
    AccountingJumps.studentHours.request(band.date, band.band);
  }

  Widget _buildNav(bool dense)
  {
    final double button = dense ? 36 : CarouselArrowButton.defaultSize;

    final Widget label = Text(
      formatMonthYear(_month),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 14 : 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppMonthButton(
            selected: _month,
            first: _firstMonth,
            last: _thisMonth,
            size: button,
            onPicked: _showMonth,
          ),
          SizedBox(width: dense ? 8 : 12),
          CarouselArrowButton(
            icon: Icons.chevron_left_rounded,
            isDisabled: !_month.isAfter(_firstMonth),
            size: button,
            onTap: () => _showMonth(DateTime(_month.year, _month.month - 1)),
          ),
          SizedBox(width: dense ? 6 : 8),
          SizedBox(width: dense ? _denseMonthLabelWidth : _monthLabelWidth, child: Center(child: label)),
          SizedBox(width: dense ? 6 : 8),
          CarouselArrowButton(
            icon: Icons.chevron_right_rounded,
            isDisabled: !_month.isBefore(_thisMonth),
            size: button,
            onTap: () => _showMonth(DateTime(_month.year, _month.month + 1)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(StudentMonth data) async
  {
    if (_exporting)
    {
      return;
    }

    setState(() => _exporting = true);

    await exportAccountingPdf(
      context,
      title: monthlyStudentsPdfTab(data.month),
      fileName: monthlyStudentsPdfFile(data.month),
      bytes: () => buildStudentMonthPdf(data),
    );

    if (mounted)
    {
      setState(() => _exporting = false);
    }
  }

  Widget _buildHeading(StudentMonth data, bool dense)
  {
    final Widget status = data.finished
        ? const BandStatePill(
            label: kMonthFinished,
            icon: Icons.check_rounded,
            accent: AppTheme.trialTealDeep,
            surface: AppTheme.todaySurface,
          )
        : const BandStatePill(label: kLiveStatus, accent: AppTheme.trialTealDeep, surface: Colors.white);

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              studentsCount(data.rows.length),
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: dense ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
          status,
        ],
      ),
    );
  }

  Widget _buildBody(StudentMonth data, bool dense)
  {
    if (data.rows.isEmpty)
    {
      return AppEmptyRoom(
        card: const AppEmptyCard(icon: Icons.event_note_rounded, message: kNoConfirmedHours),
        below: [
          if (data.pending.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: PendingBandsNote(pending: data.pending, onOpen: _openBand, centered: true),
            ),
        ],
      );
    }

    // Each block runs in after the one above it, as on the other pages.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.header, child: _buildHeading(data, dense)),
        const SizedBox(height: kPageHeadingGap),
        Expanded(
          child: PageTransitionScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.list,
                    child: StudentMonthTable(month: data, onOpenStudent: _openStudent, onOpenBand: _openBand),
                  ),
                  const SizedBox(height: 18),
                  PageTransitionItem(
                    slot: PageTransitionItem.list + 1,
                    child: Center(
                      child: AppGradientButton(
                        label: kExportPdf,
                        icon: Icons.picture_as_pdf_outlined,
                        width: _exportWidth,
                        height: 50,
                        fontSize: 14,
                        busy: _exporting,
                        onPressed: () => unawaited(_exportPdf(data)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final StudentMonth? data = _data;
    final Object? error = _error;

    final Widget body = switch ((data, error))
    {
      (_, final Object failure) when data == null => AppLoadFailedRoom(
          error: failure,
          message: readableApiError(failure),
          onRetry: _load,
        ),
      (final StudentMonth month, _) => _buildBody(month, dense),
      _ => const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.frame, child: _buildNav(dense)),
        SizedBox(height: dense ? 14 : 18),
        Expanded(child: body),
      ],
    );
  }
}
