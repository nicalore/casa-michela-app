import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_choice_card.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../legal_documents.dart';

const double _maxWidth = 960;
const double _gap = 20;

// Below this the three documents go one under the other.
const double _tilesInRowFrom = 720;

class OnboardingTermsStep extends StatelessWidget
{
  final bool accepted;
  final ValueChanged<bool> onChanged;
  const OnboardingTermsStep({
    super.key,
    required this.accepted,
    required this.onChanged,
  });

  Widget _buildDocuments()
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final List<Widget> tiles = [for (final document in kLegalDocuments) _DocumentTile(document)];

        if (constraints.maxWidth < _tilesInRowFrom)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                IntrinsicHeight(child: tiles[i]),
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: pageTransitionBlocks([
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDocuments(),
                    const SizedBox(height: _gap),
                    AppChoiceCard(
                      icon: Icons.task_alt_rounded,
                      title: kTermsDeclaration,
                      selected: accepted,
                      onSelected: onChanged,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatefulWidget
{
  final LegalDocument document;

  const _DocumentTile(this.document);

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final LegalDocument document = widget.document;

    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => openLegalDocument(document),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _hover ? AppTheme.trialGold : AppTheme.trialLine, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(gradient: AppTheme.brandGradient, shape: BoxShape.circle),
                  child: Icon(document.icon, size: 22, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  document.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialOcean,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  document.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: AppTheme.trialMutedText,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'LEGGI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.open_in_new_rounded, size: 17, color: AppTheme.trialTealDeep),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
