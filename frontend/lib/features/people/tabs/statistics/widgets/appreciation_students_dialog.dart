import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../services/api_service.dart';
import '../../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../../shared/widgets/dialog_components.dart';
import '../../../../../shared/widgets/snackbar.dart';
import '../../../../lessons/models/person_option_item.dart';
import '../../../../lessons/widgets/person_avatar.dart';
import '../../../models/personal_statistics_items.dart';
import '../../../widgets/person_detail_widgets.dart';
import 'stat_widgets.dart';
import 'stats_data.dart';

const double _dialogWidth = 560;

// The pupils behind one of a teacher's thumbs, each named once, for the
// period the card was showing. Fetched before the window opens, so it opens
// at its final size.
Future<void> showAppreciationStudentsDialog(
  BuildContext context, {
  required String taxCode,
  required String period,
  required bool up,
}) async
{
  final TeacherAppreciationStudentsItem students;

  try
  {
    final parts = statsPeriodParts(period);

    students = await ApiService().getTeacherAppreciationStudents(
      taxCode,
      months: parts.months,
      year: parts.year,
      month: parts.month,
    );
  }
  catch (e)
  {
    if (context.mounted)
    {
      CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
    }

    return;
  }

  if (!context.mounted)
  {
    return;
  }

  showBlurredDialog(
    context: context,
    barrierLabel: 'AppreciationStudents',
    builder: (context) => AppreciationStudentsDialog(
      period: period,
      up: up,
      students: up ? students.preferring : students.avoiding,
    ),
  );
}

class AppreciationStudentsDialog extends StatelessWidget
{
  final String period;
  final bool up;

  // One side only, already told apart by the thumb that was tapped.
  final List<PersonOptionItem> students;

  const AppreciationStudentsDialog({
    super.key,
    required this.period,
    required this.up,
    required this.students,
  });

  // The whole top pill: which thumb, how many, over what period.
  Widget _buildHeader()
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThumbCount(up: up, count: students.length, large: true),
        const SizedBox(width: 16),
        Text(
          statsPeriodLabel(period),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(PersonOptionItem student)
  {
    return Row(
      children: [
        PersonAvatar(person: student, size: PersonAvatar.listSize),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            student.fullName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody()
  {
    if (students.isEmpty)
    {
      return const PersonEmptyState(message: 'Nessuno studente.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < students.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _buildRow(students[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      header: _buildHeader(),
      maxWidth: _dialogWidth,
      children: [
        AppDialogPill(expand: true, child: _buildBody()),
      ],
    );
  }
}
