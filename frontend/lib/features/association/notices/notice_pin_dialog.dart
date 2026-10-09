import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_calendar_button.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/dialog_components.dart';
import 'notice_item.dart';
import 'notice_strings.dart';

const double _dialogWidth = 520;
const int _defaultDays = 7;
const int _furthestDays = 365;
const Duration _fade = Duration(milliseconds: 220);

typedef NoticePinChoice = ({DateTime? until});

// Null when dismissed; until null pins it until someone unpins it.
Future<NoticePinChoice?> askNoticePin(BuildContext context, NoticeSummaryItem notice)
{
  return showBlurredDialog<NoticePinChoice>(
    context: context,
    barrierLabel: 'NoticePin',
    builder: (_) => _NoticePinDialog(notice: notice),
  );
}

class _NoticePinDialog extends StatefulWidget
{
  final NoticeSummaryItem notice;

  const _NoticePinDialog({required this.notice});

  @override
  State<_NoticePinDialog> createState() => _NoticePinDialogState();
}

class _NoticePinDialogState extends State<_NoticePinDialog>
{
  late final DateTime _today = _dayOf(romeNow());

  late DateTime _until = _today.add(const Duration(days: _defaultDays));

  bool _forever = true;

  static DateTime _dayOf(DateTime instant) => DateTime(instant.year, instant.month, instant.day);

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kPinEyebrow,
      title: widget.notice.title,
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kPinConfirm,
          icon: Icons.push_pin_rounded,
          height: 52,
          fontSize: 14,
          onPressed: () => Navigator.of(context).pop((until: _forever ? null : _until)),
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmentedSwitch(
                value: _forever,
                trueLabel: kPinForever,
                falseLabel: kPinUntilDay,
                onChanged: (forever) => setState(() => _forever = forever),
              ),
              const SizedBox(height: 22),
              // Kept in place while hidden, so the dialog never changes height.
              AnimatedOpacity(
                opacity: _forever ? 0 : 1,
                duration: _fade,
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _forever,
                  child: Row(
                    children: [
                      // Label and day share one baseline, whatever their sizes.
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const AppFieldLabel(kPinUntilLabel),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                '${formatWeekdayColumnLabel(_until)} ${_until.year}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.trialInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppCalendarButton(
                        selected: _until,
                        today: _today,
                        first: _today,
                        last: _today.add(const Duration(days: _furthestDays)),
                        onPicked: (day) => setState(() => _until = _dayOf(day)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
