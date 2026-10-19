import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/notices/notice_format.dart';
import '../report_item.dart';
import '../report_strings.dart';
import '../reports_board.dart';

const double _dialogWidth = 800;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _labelColumn = 180;

// Wide enough for the resolve label on one line.
const double _footerWidth = 660;

// Opening it reads it; shown over whatever is on screen, the page or a home.
Future<void> openReport(BuildContext context, int id) async
{
  final ReportItem report;

  try
  {
    report = await ApiService().openReport(id);
  }
  catch (error)
  {
    if (context.mounted)
    {
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }

    return;
  }

  ReportsBoard.instance.opened(report);

  if (!context.mounted)
  {
    return;
  }

  await showBlurredDialog<void>(
    context: context,
    barrierLabel: 'ReportDetails',
    builder: (dialogContext) => _ReportDetails(report: report),
  );
}

class _ReportDetails extends StatefulWidget
{
  final ReportItem report;

  const _ReportDetails({required this.report});

  @override
  State<_ReportDetails> createState() => _ReportDetailsState();
}

class _ReportDetailsState extends State<_ReportDetails>
{
  bool _busy = false;

  ReportItem get _report => widget.report;

  TextStyle get _valueStyle => GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.trialInk);

  Future<void> _resolve() async
  {
    if (_busy)
    {
      return;
    }

    setState(() => _busy = true);

    try
    {
      await ApiService().resolveReport(_report.id);
    }
    catch (error)
    {
      if (mounted)
      {
        setState(() => _busy = false);
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }

      return;
    }

    ReportsBoard.instance.resolved(_report.id);

    if (!mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: kResolved);
    Navigator.of(context).pop();
  }

  Widget _row(String label, String value, {bool first = false})
  {
    return Container(
      padding: EdgeInsets.only(top: first ? 0 : 10, bottom: 10),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: AppTheme.trialLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: _labelColumn, child: AppFieldLabel(label)),
          Expanded(child: SelectableText(value, style: _valueStyle)),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
      );

  Widget _words(String text)
  {
    return SelectableText(
      text,
      style: GoogleFonts.plusJakartaSans(fontSize: 16.5, fontWeight: FontWeight.w500, height: 1.6, color: AppTheme.trialInk),
    );
  }

  List<Widget> _body()
  {
    final String? description = _report.description;

    if (_report.kind == ReportKind.personalData)
    {
      return [
        const SizedBox(height: 14),
        const AppEyebrow(kCorrectionsHeading),
        const SizedBox(height: 10),
        for (final (index, correction) in _report.corrections.indexed)
          _row(correction.field, correction.value, first: index == 0),
      ];
    }

    if (description == null || description.isEmpty)
    {
      return const [];
    }

    return [_divider(), _words(description)];
  }

  Widget _note()
  {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          const Icon(Icons.mail_rounded, size: 20, color: AppTheme.trialTealDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resolveNote(_report.reporterName),
              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String? role = _report.reporterRole;
    final String? person = _report.personTaxCode;

    return AppDialogStack(
      eyebrow: _report.kind.label,
      title: reportTitle(_report),
      maxWidth: _dialogWidth,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kResolveButton,
          icon: Icons.check_rounded,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          busy: _busy,
          onPressed: _resolve,
        ),
        maxWidth: _footerWidth,
      ),
      children: [
        AppScrollingDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(kDateLabel, noticeSentLong(_report.createdAt), first: true),
              _row(kSentByLabel, _report.reporterName),
              if (role != null) _row(kRoleLabel, role),
              _row(kEmailLabel, _report.reporterEmail),
              if (person != null) _row(kTaxCodeLabel, person),
              ..._body(),
              _note(),
            ],
          ),
        ),
      ],
    );
  }
}
