import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_transition.dart';

class InfoTab extends StatelessWidget
{
  const InfoTab({super.key});

  @override
  Widget build(BuildContext context)
  {
    final int currentYear = DateTime.now().year;
    const String appVersion = '0.1.1';

    final List<String> documents = [
      'Condizioni d\'uso',
      'Privacy policy',
      'Statuto dell\'Associazione',
      'Regolamento dell\'Associazione',
    ];

    return SingleChildScrollView(
      // The side padding is on top of the page's own margin, which is why it
      // goes on a narrow window: sixteen and thirty-two together are a fifth of
      // a phone screen spent on air.
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
              ...documents.map((title)
              {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _InfoDocumentCard(title: title, onTap: () {}),
                );
              }),
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
            // Gold under the pointer, the same mark a module card on the
            // dashboard takes: on a page of white rows it is the one warm thing
            // on screen, so the row being pointed at needs no other signal.
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
