import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../utils/booking_window.dart';

class LessonsClosedDay extends StatelessWidget
{
  // Null where the page already names the day.
  final DateTime? day;

  final String? message;

  // Rows stored before the day was closed; still shown so they can be removed.
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
