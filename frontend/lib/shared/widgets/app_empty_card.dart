import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'page_transition.dart';
import 'scroll_edge_fade.dart';

const String kNoSearchMatch = 'Nessun elemento trovato per questa ricerca.';

class AppEmptyCard extends StatelessWidget
{
  final IconData icon;
  final String message;

  const AppEmptyCard({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: AppTheme.trialTealDeep),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              emptyCardText(message),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialTealDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The card centred in the room it is given, scrolling only when that is too short.
class AppEmptyRoom extends StatelessWidget
{
  final AppEmptyCard card;

  // Under the card, each after the gap.
  final List<Widget> below;

  final double gap;

  const AppEmptyRoom({super.key, required this.card, this.below = const [], this.gap = 28});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints) => ScrollEdgeFade(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: pageTransitionBlocks([
                  card,
                  for (final widget in below) ...[
                    SizedBox(height: gap),
                    widget,
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A badge reads as a label: the closing full stop of a message goes.
String emptyCardText(String message)
{
  return message.endsWith('.') ? message.substring(0, message.length - 1) : message;
}

// Null while something is shown; the search card when only the search left nothing.
AppEmptyCard? emptyListCard({
  required int shown,
  required int total,
  required IconData icon,
  required String none,
})
{
  if (shown > 0)
  {
    return null;
  }

  return total == 0
      ? AppEmptyCard(icon: icon, message: none)
      : const AppEmptyCard(icon: Icons.search_off_rounded, message: kNoSearchMatch);
}
