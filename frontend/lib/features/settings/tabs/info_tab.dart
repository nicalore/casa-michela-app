import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/pdf_tab.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/association_logo.dart';
import '../../../shared/widgets/snackbar.dart';
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

    final PdfTab? tab = openPdfTab(title: kRegulationTitle);

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
      tab?.fail(kRegulationOpenFailed);

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
    final List<(IconData, String, VoidCallback)> documents = [
      (Icons.gavel_rounded, kStatuteTitle, () {}),
      (Icons.menu_book_rounded, kRegulationTitle, _openRegulation),
      (Icons.description_rounded, kTermsTitle, () {}),
      (Icons.privacy_tip_rounded, kPrivacyTitle, () {}),
    ];

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
                final int columns = constraints.maxWidth >= 2 * _minDocumentWidth + _documentGap ? 2 : 1;
                final double width = (constraints.maxWidth - (columns - 1) * _documentGap) / columns;

                return Wrap(
                  spacing: _documentGap,
                  runSpacing: _documentGap,
                  children: [
                    for (final (icon, title, onTap) in documents)
                      SizedBox(
                        width: width,
                        child: _InfoDocumentCard(icon: icon, title: title, onTap: onTap),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.trialTealDeep.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      kAppVersionLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(appCopyright(DateTime.now().year), style: settingsLineStyle()),
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
                  const AssociationLogo(size: _logoSize),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kAssociationName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialOcean,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                children: [who, const SizedBox(height: 20), report],
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.trialGoldSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, size: 20, color: AppTheme.trialGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kDevelopmentWarning,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_documentRadius),
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              SettingsIconTile(icon: widget.icon),
              const SizedBox(width: 14),
              Expanded(child: Text(widget.title, style: settingsTitleStyle())),
              const SizedBox(width: 12),
              Icon(
                Icons.open_in_new_rounded,
                color: _isHovering ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
