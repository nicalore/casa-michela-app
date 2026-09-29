import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../../shared/widgets/association_logo.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_glass_list.dart';

const double _badgeSize = 34;
const double _rowLeft = 14;
const double _rowGap = 13;

const double _logoSize = 58;

// Two lines of warning on a phone rather than three.
const double _creditsWidth = 340;

// Only the regulation exists yet; the others do nothing, as on the desktop.
class MobileDocumentsCard extends StatelessWidget
{
  final VoidCallback onRegulation;

  final bool regulationBusy;

  const MobileDocumentsCard({super.key, required this.onRegulation, required this.regulationBusy});

  Widget _download({bool busy = false})
  {
    return SizedBox.square(
      dimension: 26,
      child: Center(
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.trialTealDeep),
              )
            : Icon(Icons.download_rounded, size: 23, color: AppTheme.trialInk.withValues(alpha: 0.36)),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<(IconData, String, VoidCallback?)> documents = [
      (Icons.gavel_rounded, kStatuteTitle, null),
      (Icons.menu_book_rounded, kRegulationTitle, onRegulation),
      (Icons.description_rounded, kTermsTitle, null),
      (Icons.privacy_tip_rounded, kPrivacyTitle, null),
    ];

    return MobileGlassList(
      indent: _rowLeft + _badgeSize + _rowGap,
      rows: [
        for (final (icon, title, onTap) in documents)
          MobileGlassListRow(
            leading: MobileCardBadge(icon: icon),
            title: title,
            trailing: _download(busy: title == kRegulationTitle && regulationBusy),
            onTap: onTap,
          ),
      ],
    );
  }
}

class MobileAppCredits extends StatelessWidget
{
  final int year;

  const MobileAppCredits({super.key, required this.year});

  @override
  Widget build(BuildContext context)
  {
    TextStyle style(double alpha)
    {
      return GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.6,
        color: Colors.white.withValues(alpha: alpha),
      );
    }

    return Column(
      children: [
        const AssociationLogo(size: _logoSize),
        const SizedBox(height: 18),
        Text(appCredits(year), textAlign: TextAlign.center, style: style(0.88)),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _creditsWidth),
          child: Text(kDevelopmentWarning, textAlign: TextAlign.center, style: style(0.78)),
        ),
      ],
    );
  }
}
