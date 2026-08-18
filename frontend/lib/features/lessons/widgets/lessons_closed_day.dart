import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../utils/booking_window.dart';

// What a day the association does not open looks like.
//
// Everything that asks something of you goes: the search field searches a list
// that cannot exist, and the button opens a window where every band is shut. A
// day nobody can be booked on has one thing to say and says it.
class LessonsClosedDay extends StatelessWidget
{
  // Which day is shut, or null where the page says it already: the calendar
  // keeps its row of arrows above this notice, and the date written twice one
  // under the other is the same answer given to nobody's question.
  final DateTime? day;

  // What cannot be done here, said in the words of the list that would have
  // been shown — or null where there is nothing to add to the closure itself.
  final String? message;

  // Whatever was stored before the day was closed. It is shown all the same:
  // hours given while the association still opened do not stop existing because
  // it has since shut, and hiding them would leave rows nobody could reach to
  // take away.
  final List<Widget> leftovers;

  const LessonsClosedDay({
    super.key,
    this.day,
    this.message,
    this.leftovers = const [],
  });

  @override
  Widget build(BuildContext context)
  {
    // On a change of page this leaves and comes back like any other content: the
    // notice as the head of it, and what was stored before the closure card by
    // card under it. Left whole it was the one screen of the module that stood
    // still while the rest of the app walked off.
    return PageTransitionScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTransitionItem(
            slot: PageTransitionItem.header,
            child: Padding(
              padding: const EdgeInsets.only(top: 56, bottom: 8),
              child: Column(
                children: [
                  const Icon(Icons.event_busy_rounded, size: 52, color: AppTheme.trialMutedText),
                  const SizedBox(height: 20),
                  Text(
                    "L'associazione è chiusa",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: AppTheme.trialOcean,
                    ),
                  ),
                  if (day != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formatAvailableDayLabel(day!),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                  ],
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (leftovers.isNotEmpty) ...[
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
            EntityCardGrid(children: leftovers),
          ],
        ],
      ),
    );
  }
}
