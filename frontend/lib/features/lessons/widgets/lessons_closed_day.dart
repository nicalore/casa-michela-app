import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../calendar/utils/calendar_strings.dart';

class LessonsClosedDay extends StatelessWidget
{
  final String? message;

  // Rows stored before the day was closed; still shown so they can be removed.
  final List<Widget> leftovers;

  const LessonsClosedDay({
    super.key,
    this.message,
    this.leftovers = const [],
  });

  @override
  Widget build(BuildContext context)
  {
    final AppEmptyCard card = AppEmptyCard(
      icon: Icons.event_busy_rounded,
      message: kAssociationClosedTitle,
      detail: message,
    );

    if (leftovers.isEmpty)
    {
      return AppEmptyRoom(card: card);
    }

    return PageTransitionScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTransitionItem(
            slot: PageTransitionItem.header,
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Center(child: card),
            ),
          ),
          const SizedBox(height: 40),
          PageTransitionItem(
            slot: PageTransitionItem.list,
            child: Text(
              'Inserite prima della chiusura',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
          const SizedBox(height: 16),
          EntityCardGrid(denseWidth: kDenseWideCardWidth, children: leftovers),
        ],
      ),
    );
  }
}
