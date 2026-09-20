import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/pdf_tab.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../widgets/problem_report_dialog.dart';

const String _regulationTitle = 'Regolamento dell\'Associazione';

// Matches the own page's report pill.
const double _reportHeight = 50;
const double _reportRadius = 25;
const double _reportFontSize = 14;

class InfoTab extends StatefulWidget
{
  const InfoTab({super.key});

  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab>
{
  bool _isOpeningRegulation = false;

  // The tab must open before the first await, or the browser blocks it as a popup.
  Future<void> _openRegulation() async
  {
    if (_isOpeningRegulation)
    {
      return;
    }

    final PdfTab? tab = openPdfTab(title: _regulationTitle);

    setState(() => _isOpeningRegulation = true);

    try
    {
      final ApiFile regulation = await ApiService().fetchRegulation();

      if (tab != null)
      {
        tab.present(regulation.bytes, fileName: regulation.fileName);
      }
      else if (downloadPdf(regulation.bytes, fileName: regulation.fileName) && mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Il browser ha bloccato la scheda: il regolamento è stato scaricato.',
          isError: false,
        );
      }
    }
    catch (e)
    {
      tab?.fail('Non è stato possibile aprire il regolamento.');

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isOpeningRegulation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final int currentYear = DateTime.now().year;
    const String appVersion = '0.2.3';

    final List<(String, VoidCallback)> documents = [
      ('Statuto dell\'Associazione', () {}),
      (_regulationTitle, _openRegulation),
      ('Termini e condizioni', () {}),
      ('Privacy policy', () {}),
    ];

    return PageTransitionScrollView(
      child: Padding(
        // Side padding adds to the page margin, so it is dropped when compact.
        padding: EdgeInsets.only(
          top: 16,
          left: AppBreakpoints.of(context).isCompact ? 0 : 32,
          right: AppBreakpoints.of(context).isCompact ? 0 : 32,
          bottom: 32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                for (final (title, onTap) in documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _InfoDocumentCard(title: title, onTap: onTap),
                  ),
                const SizedBox(height: 24),
                Center(
                  child: AppGradientButton(
                    label: 'SEGNALA UN PROBLEMA',
                    icon: Icons.flag_rounded,
                    gradient: AppTheme.dismissGradient,
                    accent: AppTheme.trialViolet,
                    height: _reportHeight,
                    radius: _reportRadius,
                    fontSize: _reportFontSize,
                    onPressed: () => showProblemReportDialog(context),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  '© $currentYear Nicolò Calore\nVersione $appVersion\nATTENZIONE: Applicazione attualmente in sviluppo. Potrebbero verificarsi comportamenti inaspettati.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.trialMutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoDocumentCard extends StatefulWidget
{
  final String title;
  final VoidCallback onTap;

  const _InfoDocumentCard({required this.title, required this.onTap});

  @override
  State<_InfoDocumentCard> createState() => _InfoDocumentCardState();
}

class _InfoDocumentCardState extends State<_InfoDocumentCard>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: _isHovering ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
