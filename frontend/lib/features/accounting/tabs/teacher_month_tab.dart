import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/search_terms.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/file_download.dart';
import '../../../shared/export/pdf_tab.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/app_month_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/search_reveal.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../lessons/widgets/lessons_day_bar.dart';
import '../../people/utils/compensation_strings.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../accounting_page.dart';
import '../export/accounting_pdf_export.dart';
import '../export/teacher_month_pdf.dart';
import '../models/teacher_month_items.dart';
import '../utils/accounting_jump.dart';
import '../utils/accounting_strings.dart';
import '../widgets/receipt_cell.dart';
import '../widgets/summary_search.dart';
import '../widgets/teacher_month_table.dart';

const double _monthLabelWidth = 200;
const double _exportWidth = 300;
const double _denseMonthLabelWidth = 160;

// Accounting reaches back to the association's first month.
final DateTime _firstMonth = DateTime(2023, 1);

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

class TeacherMonthTab extends StatefulWidget
{
  // On screen among the page's summaries: shown again, it reads the month anew.
  final bool shown;

  const TeacherMonthTab({super.key, this.shown = true});

  @override
  State<TeacherMonthTab> createState() => _TeacherMonthTabState();
}

class _TeacherMonthTabState extends State<TeacherMonthTab> with DestinationRefresh
{
  // Kept while the app runs: back from a teacher's pay, the same month shows.
  static DateTime? _shownMonth;

  final ApiService _api = ApiService();

  late DateTime _thisMonth = _monthOf(romeNow());
  late DateTime _month = _shownMonth ?? _thisMonth;

  TeacherMonth? _data;
  Object? _error;

  // Rules picked and not saved yet: leaving the screen drops them.
  final Map<String, VolunteeringRule> _chosen = {};
  String? _saving;

  // A later answer for another month drops an earlier one.
  int _request = 0;

  bool _exporting = false;

  // Receipts on their way, by tax code; the row a file is dragged over.
  final Set<String> _receiptBusy = {};
  String? _dropOver;

  // Who is looked for by name: kept across months.
  final TextEditingController _searchText = TextEditingController();
  final ValueNotifier<SearchTerms?> _search = ValueNotifier(null);

  @override
  void initState()
  {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose()
  {
    _searchText.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TeacherMonthTab oldWidget)
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
    _chosen.clear();

    if (_month.isAfter(_thisMonth))
    {
      _month = _thisMonth;
    }

    try
    {
      final TeacherMonth data = await _api.getTeachersMonth(_month);

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

  // Picked only: saved by the button beside the switch.
  void _chooseRule(TeacherMonthRow row, VolunteeringRule rule)
  {
    setState(()
    {
      if (rule == row.volunteering)
      {
        _chosen.remove(row.taxCode);
      }
      else
      {
        _chosen[row.taxCode] = rule;
      }
    });
  }

  Future<void> _confirmRule(TeacherMonthRow row) async
  {
    final VolunteeringRule? rule = _chosen[row.taxCode];

    if (rule == null || _saving != null)
    {
      return;
    }

    final DateTime month = _month;

    setState(() => _saving = row.taxCode);

    try
    {
      final TeacherMonth data = await _api.setMonthVolunteering(month, row.taxCode, rule);

      // Another month is shown by now: its own load has the last word.
      if (mounted && month == _month)
      {
        setState(()
        {
          _data = data;
          _chosen.remove(row.taxCode);
        });
      }
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
      if (mounted)
      {
        setState(() => _saving = null);
      }
    }
  }

  Future<void> _pickReceipt(TeacherMonthRow row) async
  {
    final ApiFile file;

    try
    {
      final PlatformFile? picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: kReceiptExtensions);

      if (picked == null)
      {
        return;
      }

      // Measured before it is read: a file too large never leaves the computer.
      if ((await picked.length() ?? 0) > kReceiptMaxBytes)
      {
        _refuse(kReceiptTooLarge);

        return;
      }

      file = (bytes: await picked.readAsBytes(), fileName: picked.name);
    }
    catch (_)
    {
      _refuse(kReceiptNotRead);

      return;
    }

    await _upload(row, file);
  }

  Future<void> _dropReceipt(TeacherMonthRow row, DropItem item) async
  {
    final Uint8List bytes;

    try
    {
      bytes = await item.readAsBytes();
    }
    catch (_)
    {
      _refuse(kReceiptNotRead);

      return;
    }

    if (bytes.length > kReceiptMaxBytes)
    {
      _refuse(kReceiptTooLarge);

      return;
    }

    await _upload(row, (bytes: bytes, fileName: item.name));
  }

  void _dragReceipt(TeacherMonthRow row, bool over)
  {
    if (over && _dropOver != row.taxCode)
    {
      setState(() => _dropOver = row.taxCode);
    }
    else if (!over && _dropOver == row.taxCode)
    {
      setState(() => _dropOver = null);
    }
  }

  Future<void> _upload(TeacherMonthRow row, ApiFile file) async
  {
    if (_receiptBusy.contains(row.taxCode))
    {
      return;
    }

    final bool replacing = row.receipt != null;
    final DateTime month = _month;

    setState(() => _receiptBusy.add(row.taxCode));

    try
    {
      final TeacherMonth data = await _api.uploadPaymentReceipt(month, row.taxCode, file);

      if (mounted && month == _month)
      {
        setState(() => _data = data);
        CustomSnackBar.show(context: context, message: replacing ? kReceiptReplaced : kReceiptUploaded);
      }
    }
    catch (error)
    {
      _refuse(readableApiError(error));
    }
    finally
    {
      if (mounted)
      {
        setState(() => _receiptBusy.remove(row.taxCode));
      }
    }
  }

  // Call it straight from the tap: the tab opens before the first await, or the browser blocks it.
  Future<void> _openReceipt(TeacherMonthRow row) async
  {
    final PaymentReceipt? receipt = row.receipt;

    if (receipt == null)
    {
      return;
    }

    final PdfTab? tab = openPdfTab(title: receiptTabTitle(row.fullName, _month), waiting: kReceiptWaiting);

    try
    {
      final Uint8List bytes = await _api.getPaymentReceipt(_month, row.taxCode);

      if (tab == null)
      {
        await downloadFile(bytes, fileName: receipt.fileName, mimeType: receipt.contentType);

        if (mounted)
        {
          CustomSnackBar.show(context: context, message: kReceiptDownloaded);
        }
      }
      else if (receipt.isPdf)
      {
        tab.present(bytes, fileName: receipt.fileName);
      }
      else
      {
        tab.presentImage(bytes, fileName: receipt.fileName, mimeType: receipt.contentType);
      }
    }
    catch (error)
    {
      final String message = readableApiError(error);

      tab?.fail(message);
      _refuse(message);
    }
  }

  Future<void> _deleteReceipt(TeacherMonthRow row) async
  {
    final DateTime month = _month;

    if (_receiptBusy.contains(row.taxCode) || !await confirmReceiptDeletion(context) || !mounted)
    {
      return;
    }

    setState(() => _receiptBusy.add(row.taxCode));

    try
    {
      final TeacherMonth data = await _api.deletePaymentReceipt(month, row.taxCode);

      if (mounted && month == _month)
      {
        setState(() => _data = data);
        CustomSnackBar.show(context: context, message: kReceiptDeleted);
      }
    }
    catch (error)
    {
      _refuse(readableApiError(error));
    }
    finally
    {
      if (mounted)
      {
        setState(() => _receiptBusy.remove(row.taxCode));
      }
    }
  }

  void _refuse(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  // Their record, on the pay of this month; its way back leads here.
  void _openTeacher(TeacherMonthRow row)
  {
    final String month = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

    context.go(
      Uri(
        path: '/people/${row.taxCode}',
        queryParameters: {'from': kAccountingRoute, 'section': kCompensationSection, 'month': month},
      ).toString(),
    );
  }

  // The page turns to the daily summary of that band.
  void _openBand(PendingBand band)
  {
    AccountingJumps.teacherHours.request(band.date, band.band);
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

    // The search at the left, the month on the right.
    return SummaryToolbar(
      gap: dense ? 16 : 24,
      runGap: dense ? 10 : 14,
      search: AppSearchField(
        controller: _searchText,
        hintText: kTeacherHint,
        onChanged: (text) => _search.value = SearchTerms.of(text),
      ),
      controls: Row(
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

  // The month as last read: rules picked and not saved are left out.
  Future<void> _exportPdf(TeacherMonth data) async
  {
    if (_exporting)
    {
      return;
    }

    setState(() => _exporting = true);

    await exportAccountingPdf(
      context,
      title: monthlyPdfTab(data.month),
      fileName: monthlyPdfFile(data.month),
      bytes: () => buildTeacherMonthPdf(data),
    );

    if (mounted)
    {
      setState(() => _exporting = false);
    }
  }

  Widget _buildHeading(TeacherMonth data, bool dense)
  {
    final Widget status = data.finished
        ? BandStatePill(
            label: kMonthFinished,
            icon: Icons.check_rounded,
            accent: AppTheme.trialTealDeepText,
            surface: AppTheme.todaySurface,
          )
        : BandStatePill(label: kLiveStatus, accent: AppTheme.trialTealDeepText, surface: AppTheme.surface);

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              teachersCount(data.rows.length),
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

  Widget _buildBody(TeacherMonth data, bool dense)
  {
    if (data.rows.isEmpty)
    {
      return AppEmptyRoom(
        card: AppEmptyCard(icon: Icons.event_note_rounded, message: kNoConfirmedHours),
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
                    child: SearchReveal(
                      search: _search,
                      child: TeacherMonthTable(
                        month: data,
                        chosen: _chosen,
                        saving: _saving,
                        onRule: _chooseRule,
                        onConfirmRule: (row) => unawaited(_confirmRule(row)),
                        onOpenTeacher: _openTeacher,
                        onOpenBand: _openBand,
                        receiptBusy: _receiptBusy,
                        dropOver: _dropOver,
                        onUploadReceipt: (row) => unawaited(_pickReceipt(row)),
                        onOpenReceipt: (row) => unawaited(_openReceipt(row)),
                        onDeleteReceipt: (row) => unawaited(_deleteReceipt(row)),
                        onDropReceipt: (row, file) => unawaited(_dropReceipt(row, file)),
                        onDragReceipt: _dragReceipt,
                        search: _search,
                      ),
                    ),
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
    final TeacherMonth? data = _data;
    final Object? error = _error;

    final Widget body = switch ((data, error))
    {
      (_, final Object failure) when data == null => AppLoadFailedRoom(
          error: failure,
          message: readableApiError(failure),
          onRetry: _load,
        ),
      (final TeacherMonth month, _) => _buildBody(month, dense),
      _ => Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
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
