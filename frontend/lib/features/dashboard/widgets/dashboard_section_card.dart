import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

// A section of the home page: a white pill on the paper, with the eyebrow and
// the title on top and below them whatever it has to say. The same grammar as
// the app's dialogs, because the home page is not somewhere apart — it is the
// first page, and has to look like the others.
class DashboardSectionCard extends StatelessWidget
{
  static const double radius = 28;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(28, 24, 28, 26);

  final String eyebrow;
  final String title;
  final Widget child;

  // Un comando in alto a destra: «vedi tutte», di solito.
  final Widget? action;

  // How tall it is at least. The sections still to come already have the size
  // they will have once filled, so the home page does not resettle the day they
  // are ready.
  final double minHeight;

  // Whether the content takes all the remaining height. True inside a row,
  // where the tallest card decides the height and the others would be left blank
  // underneath; false in a column, where the height is the one needed.
  final bool fill;

  const DashboardSectionCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.action,
    this.minHeight = 0,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: _padding,
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                          height: 1.2,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: AppTheme.trialOcean,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 16),
                  action!,
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (fill) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

// A section that is there but not there yet: it says what will be, so whoever
// opens the home page knows the place has been thought about and is not empty by
// oversight.
class DashboardComingSoon extends StatelessWidget
{
  final IconData icon;
  final String description;

  const DashboardComingSoon({
    super.key,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      // Inside a card as tall as it will be once filled, the text is centred:
      // at the top it would leave half a white box below it, which looks like a
      // drawing mistake rather than space set aside.
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: AppTheme.trialTealDeep),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In arrivo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppTheme.trialMutedText,
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
