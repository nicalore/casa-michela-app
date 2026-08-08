import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../utils/booking_window.dart';

// What a day the association does not open looks like.
//
// Everything that asks something of you goes: the search field searches a list
// that cannot exist, and the button opens a window where every band is shut. A
// day nobody can be booked on has one thing to say and says it.
class LessonsClosedDay extends StatelessWidget
{
  final DateTime day;

  // What cannot be done here, said in the words of the list that would have
  // been shown.
  final String message;

  // Whatever was stored before the day was closed. It is shown all the same:
  // hours given while the association still opened do not stop existing because
  // it has since shut, and hiding them would leave rows nobody could reach to
  // take away.
  final List<Widget> leftovers;

  const LessonsClosedDay({
    super.key,
    required this.day,
    required this.message,
    this.leftovers = const [],
  });

  @override
  Widget build(BuildContext context)
  {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
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
                const SizedBox(height: 8),
                Text(
                  formatAvailableDayLabel(day),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    message,
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
            ),
          ),
          if (leftovers.isNotEmpty) ...[
            const SizedBox(height: 40),
            Text(
              'Inserite prima della chiusura',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
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
