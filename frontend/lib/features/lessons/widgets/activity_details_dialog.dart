import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../models/activity_item.dart';
import 'calendar_activity_block.dart' show kActivityWord;

const double _detailsWidth = 560;

const double _voiceGap = 18;

const String _empty = '—';

Future<void> showActivityDetailsDialog({
  required BuildContext context,
  required ActivityItem activity,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'ActivityDetails',
    builder: (dialogContext) => _ActivityDetailsDialog(activity: activity),
  );
}

class _ActivityDetailsDialog extends StatelessWidget
{
  final ActivityItem activity;

  const _ActivityDetailsDialog({required this.activity});

  List<({String label, String value})> get _voices
  {
    final placement = activity.placement;
    final description = activity.description?.trim() ?? '';

    return [
      if (placement != null)
        (
          label: 'Orario',
          value: '${formatTimeRange(placement.startTime, placement.endTime)} · ${formatMinutes(placement.minutes)}',
        ),
      (label: 'Descrizione', value: description.isEmpty ? _empty : description),
    ];
  }

  Widget _buildVoice(String label, String value)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: value == _empty ? AppTheme.trialMutedText : AppTheme.trialInk,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final voices = _voices;

    return AppDialogStack(
      eyebrow: kActivityWord,
      title: activity.name,
      subtitle: Text(
        formatWeekdayColumnLabel(activity.date),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTheme.trialMutedText,
        ),
      ),
      maxWidth: _detailsWidth,
      children: [
        AppDialogPill(
          expand: true,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < voices.length; index++) ...[
                  if (index > 0) const SizedBox(height: _voiceGap),
                  _buildVoice(voices[index].label, voices[index].value),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
