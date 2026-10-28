import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/page_density.dart';
import '../../psychologist/psychologist_strings.dart' show kAddLabel, kCertificationsTitle, kEditLabel;
import '../../psychologist/widgets/certifications_dialog.dart' show kCertificationLabels;
import '../models/person_item.dart';
import 'card_eye.dart';
import 'person_detail_widgets.dart' show missingValue;

const String _otherCode = 'OTHER';
const String _dsaCode = 'DSA';

// One certification per line: «Altro» as its content alone, DSA with its type right under it.
class StudentCertificationsCard extends StatelessWidget
{
  final PersonItem student;
  final VoidCallback onEdit;

  const StudentCertificationsCard({super.key, required this.student, required this.onEdit});

  static String _orDash(String? value)
  {
    final String? trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? missingValue : trimmed;
  }

  Widget _buildRow(String code, bool dense)
  {
    final String? type = code == _dsaCode ? student.certificationDsaDetail?.trim() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          code == _otherCode ? _orDash(student.certificationOtherDetail) : kCertificationLabels[code]!,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 15 : 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialOcean,
          ),
        ),
        if (type != null && type.isNotEmpty) ...[
          SizedBox(height: dense ? 2 : 4),
          Text(
            type,
            style: GoogleFonts.plusJakartaSans(
              fontSize: dense ? 13.5 : 15.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRows(bool dense)
  {
    final List<String> codes = [
      for (final code in kCertificationLabels.keys)
        if (student.certificationTypes.contains(code)) code,
    ];

    if (codes.isEmpty)
    {
      return Text(
        missingValue,
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 15 : 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialInk,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (int index, String code) in codes.indexed) ...[
          if (index > 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: dense ? 12 : 18),
              child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
            ),
          _buildRow(code, dense),
        ],
      ],
    );
  }

  // [eye]: null with nothing to hide.
  Widget _buildCard(bool dense, {Widget? eye, bool hidden = false})
  {
    final bool empty = student.certificationTypes.isEmpty;

    return AppCard(
      title: kCertificationsTitle,
      compact: !dense,
      leading: AppCardBadge(icon: Icons.assignment_outlined, compact: !dense),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eye != null) ...[
            eye,
            SizedBox(width: dense ? 6 : 10),
          ],
          AppGradientButton(
            label: empty ? kAddLabel : kEditLabel,
            icon: empty ? Icons.add_rounded : Icons.edit_rounded,
            height: 40,
            radius: 20,
            fontSize: 13,
            onPressed: onEdit,
          ),
        ],
      ),
      child: hidden ? const ObscuredCardText() : _buildRows(dense),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    if (student.certificationTypes.isEmpty)
    {
      return _buildCard(dense);
    }

    return EyeMasked(builder: (context, hidden, eye) => _buildCard(dense, eye: eye, hidden: hidden));
  }
}
