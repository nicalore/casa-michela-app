import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/association_logo.dart';

const double _ruleWidth = 44;
const double _ruleHeight = 3;

class MobileBrand extends StatelessWidget
{
  final double logoSize;
  final double titleSize;

  const MobileBrand({super.key, this.logoSize = 92, this.titleSize = 21});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AssociationLogo(size: logoSize),
        SizedBox(height: titleSize),
        Text(
          'Associazione Casa Michela',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: Colors.white,
          ),
        ),
        SizedBox(height: titleSize * 0.6),
        Container(
          width: _ruleWidth,
          height: _ruleHeight,
          decoration: BoxDecoration(
            color: AppTheme.trialGold,
            borderRadius: BorderRadius.circular(_ruleHeight / 2),
          ),
        ),
      ],
    );
  }
}
