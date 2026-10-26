import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/association/notices/notice_format.dart';
import '../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../features/reports/report_item.dart';
import '../../../features/reports/report_strings.dart';
import '../../../features/reports/reports_board.dart';
import '../../../services/api_service.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../profile/widgets/mobile_detail_card.dart';

const double _titleRoom = 18;
const double _cardGap = 12;

// Read before the sheet rises, so it opens whole; opening it reads it.
Future<void> showMobileReport(BuildContext context, int id) async
{
  final ReportItem report;

  try
  {
    report = await ApiService().openReport(id);
  }
  catch (e)
  {
    if (context.mounted)
    {
      MobileNotice.show(context, readableApiError(e), error: true);
    }

    return;
  }

  ReportsBoard.instance.opened(report);

  if (!context.mounted)
  {
    return;
  }

  await showMobileSheet<void>(context: context, builder: (_) => _ReportSheet(report: report, page: context));
}

class _ReportSheet extends StatefulWidget
{
  final ReportItem report;

  // Where the outcome is told, once the sheet has gone.
  final BuildContext page;

  const _ReportSheet({required this.report, required this.page});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet>
{
  bool _busy = false;

  ReportItem get report => widget.report;

  Future<void> _resolve() async
  {
    if (_busy)
    {
      return;
    }

    setState(() => _busy = true);

    try
    {
      await ApiService().resolveReport(report.id);
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _busy = false);
        MobileNotice.show(context, readableApiError(e), error: true);
      }

      return;
    }

    ReportsBoard.instance.resolved(report.id);

    if (mounted)
    {
      closeMobileSheet(context);
    }

    if (widget.page.mounted)
    {
      MobileNotice.show(widget.page, kResolved);
    }
  }

  Widget _facts()
  {
    final String? role = report.reporterRole;
    final String? person = report.personTaxCode;

    return MobileSheetCard(
      child: MobileDetailRows(
        rows: [
          DetailRowData(kDateLabel, noticeSentLong(report.createdAt)),
          DetailRowData(kSentByLabel, report.reporterName),
          if (role != null) DetailRowData(kRoleLabel, role),
          DetailRowData(kEmailLabel, report.reporterEmail),
          if (person != null) DetailRowData(kTaxCodeLabel, person),
        ],
      ),
    );
  }

  List<Widget> _body()
  {
    if (report.kind == ReportKind.personalData)
    {
      return [
        const SizedBox(height: _cardGap),
        MobileSheetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  kCorrectionsHeading,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.trialTealDeep),
                ),
              ),
              MobileDetailRows(
                rows: [for (final correction in report.corrections) DetailRowData(correction.field, correction.value)],
              ),
            ],
          ),
        ),
      ];
    }

    final String? description = report.description;

    if (description == null || description.isEmpty)
    {
      return const [];
    }

    return [
      const SizedBox(height: _cardGap),
      MobileSheetCard(
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: SelectableText(
            description,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, height: 1.55, color: AppTheme.trialInk),
          ),
        ),
      ),
    ];
  }

  Widget _note()
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.mail_rounded, size: 19, color: AppTheme.trialTealDeep),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              resolveNote(report.reporterName),
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4, color: MobilePalette.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileSheet(
      eyebrow: report.kind.label,
      title: reportTitle(report),
      saving: _busy,
      body: [
        const SizedBox(height: _titleRoom),
        _facts(),
        ..._body(),
        _note(),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: MobileGoldButton(
          label: kResolveLabel,
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _resolve,
        ),
      ),
    );
  }
}
