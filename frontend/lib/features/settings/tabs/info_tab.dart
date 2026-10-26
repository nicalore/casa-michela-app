import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/pdf_tab.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/association_logo.dart';
import '../../../shared/widgets/snackbar.dart';
import '../utils/association_documents.dart';
import '../utils/settings_strings.dart';
import '../widgets/problem_report_dialog.dart';
import '../widgets/settings_panel.dart';

// Matches the own page's report pill.
const double _reportHeight = 50;
const double _reportRadius = 25;
const double _reportFontSize = 14;

const double _logoSize = 96;

// Narrower, the report button goes under the logo.
const double _stackedBelow = 560;

const double _cardRadius = 28;
const double _documentRadius = 22;

// Two papers side by side once each gets this much.
const double _minDocumentWidth = 300;
const double _documentGap = 20;

// Below the wide window (AppPageDensity).
const double _denseLogoSize = 60;
const double _denseCardRadius = 20;
const double _denseDocumentRadius = 16;
const double _denseDocumentGap = 12;

class InfoTab extends StatefulWidget
{
  const InfoTab({super.key});

  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab>
{
  AssociationDocument? _opening;

  // The tab must open before the first await, or the browser blocks it as a popup.
  Future<void> _open(AssociationDocument document) async
  {
    if (_opening != null)
    {
      return;
    }

    final PdfTab? tab = openPdfTab(title: document.title);

    setState(() => _opening = document);

    try
    {
      final ApiFile file = await ApiService().fetchDocument(document.path, fallbackName: document.title);

      if (tab != null)
      {
        tab.present(file.bytes, fileName: file.fileName);
      }
      else if (downloadPdf(file.bytes, fileName: file.fileName) && mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Il browser ha bloccato la scheda: il documento è stato scaricato.',
          isError: false,
        );
      }
    }
    catch (e)
    {
      tab?.fail(kDocumentOpenFailed);

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _opening = null);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final double gap = AppPageDensity.of(context) ? _denseDocumentGap : _documentGap;

    return SettingsColumn(
      children: [
        const _AboutCard(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeading(kDocumentsHeading),
            const SizedBox(height: kPageHeadingGap),
            LayoutBuilder(
              builder: (context, constraints)
              {
                final int columns = constraints.maxWidth >= 2 * _minDocumentWidth + gap ? 2 : 1;
                final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final document in AssociationDocument.values)
                      SizedBox(
                        width: width,
                        child: _InfoDocumentCard(
                          icon: document.icon,
                          title: document.title,
                          onTap: () => _open(document),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget
{
  const _AboutCard();

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(dense ? _denseCardRadius : _cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints)
            {
              final bool stacked = constraints.maxWidth < _stackedBelow;

              final Widget version = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: dense
                        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 3)
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.trialTealDeep.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      kAppVersionLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: dense ? 11.5 : 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                  ),
                  SizedBox(height: dense ? 4 : 6),
                  Text(appCopyright(DateTime.now().year), style: settingsLineStyle(dense: dense)),
                ],
              );

              final Widget report = AppGradientButton(
                label: kReportProblemLabel.toUpperCase(),
                icon: Icons.flag_rounded,
                gradient: AppTheme.dismissGradient,
                accent: AppTheme.trialViolet,
                height: _reportHeight,
                radius: _reportRadius,
                fontSize: _reportFontSize,
                onPressed: () => showProblemReportDialog(context),
              );

              final Widget who = Row(
                children: [
                  AssociationLogo(size: dense ? _denseLogoSize : _logoSize),
                  SizedBox(width: dense ? 16 : 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kAssociationName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: dense ? 17 : 23,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialOcean,
                          ),
                        ),
                        SizedBox(height: dense ? 5 : 8),
                        // The button level with the version and the copyright.
                        if (stacked)
                          version
                        else
                          Row(children: [Expanded(child: version), const SizedBox(width: 16), report]),
                      ],
                    ),
                  ),
                ],
              );

              if (!stacked)
              {
                return who;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [who, SizedBox(height: dense ? 14 : 20), report],
              );
            },
          ),
          SizedBox(height: dense ? 14 : 20),
          Container(
            padding: dense
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.trialGoldSurface,
              borderRadius: BorderRadius.circular(dense ? 12 : 16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, size: dense ? 17 : 20, color: AppTheme.trialGold),
                SizedBox(width: dense ? 8 : 10),
                Expanded(
                  child: Text(
                    kDevelopmentWarning,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: dense ? 12.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: AppTheme.modifiedAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDocumentCard extends StatefulWidget
{
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _InfoDocumentCard({required this.icon, required this.title, required this.onTap});

  @override
  State<_InfoDocumentCard> createState() => _InfoDocumentCardState();
}

class _InfoDocumentCardState extends State<_InfoDocumentCard>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // Only the border fades: the padding follows the window and must not animate.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(dense ? _denseDocumentRadius : _documentRadius),
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: dense
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                SettingsIconTile(icon: widget.icon),
                SizedBox(width: dense ? 12 : 14),
                Expanded(child: Text(widget.title, style: settingsTitleStyle(dense: dense))),
                const SizedBox(width: 12),
                Icon(
                  Icons.open_in_new_rounded,
                  color: _isHovering ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                  size: dense ? 18 : 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
