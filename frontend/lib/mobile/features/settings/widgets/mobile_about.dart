import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/settings/utils/association_documents.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../../shared/widgets/association_logo.dart';
import '../../../shared/widgets/mobile_development_warning.dart';
import '../../../shared/widgets/mobile_nav_sheet.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_glass_list.dart';

const double _badgeSize = 34;
const double _rowLeft = 14;
const double _rowGap = 13;

const double _logoSize = 58;
const double _warningGap = 16;

class MobileDocumentsCard extends StatelessWidget
{
  final ValueChanged<AssociationDocument> onDocument;

  // The one being saved, if any.
  final AssociationDocument? busy;

  const MobileDocumentsCard({super.key, required this.onDocument, required this.busy});

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
    return MobileGlassList(
      indent: _rowLeft + _badgeSize + _rowGap,
      rows: [
        for (final document in AssociationDocument.values)
          MobileGlassListRow(
            leading: MobileCardBadge(icon: document.icon),
            title: document.title,
            trailing: _download(busy: document == busy),
            onTap: () => onDocument(document),
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
        const SizedBox(height: _warningGap),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MobileNavSheet.tabletWidth),
          child: const MobileDevelopmentWarning(kDevelopmentWarning),
        ),
      ],
    );
  }
}
