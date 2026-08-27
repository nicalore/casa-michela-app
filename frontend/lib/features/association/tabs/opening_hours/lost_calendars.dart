import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/dialog_components.dart';
import '../../../lessons/models/lesson_item.dart' show LessonItem;

// The server computes what an opening-hours write would take away and refuses
// it until confirmed; this side only asks the question.

class LostCalendar
{
  final DateTime date;
  final TimeBucket band;

  // True: the band loses all hours and its published calendar. False: the band
  // stays open the other way; only the closed mode's lessons and the
  // publication are lost.
  final bool whole;

  const LostCalendar({
    required this.date,
    required this.band,
    required this.whole,
  });

  factory LostCalendar.fromJson(Map<String, dynamic> json)
  {
    return LostCalendar(
      date: DateTime.parse(json['date'] as String),
      band: LessonItem.parseBand(json['band']),
      whole: json['whole'] as bool? ?? true,
    );
  }

  String get said =>
      '${formatWeekdayColumnLabel(date)} · ${bandLabel(band).toLowerCase()}';
}

class LostHours
{
  final int availabilities;
  final int presences;
  final int lessons;

  const LostHours({
    this.availabilities = 0,
    this.presences = 0,
    this.lessons = 0,
  });

  factory LostHours.fromJson(Map<String, dynamic> json)
  {
    return LostHours(
      availabilities: json['availabilities'] as int? ?? 0,
      presences: json['presences'] as int? ?? 0,
      lessons: json['lessons'] as int? ?? 0,
    );
  }

  bool get any => availabilities > 0 || presences > 0 || lessons > 0;

  // Italian verb agreement: singular only when exactly one thing is lost.
  bool get isSingle => availabilities + presences + lessons == 1;

  static String _counted(int value, String singular, String plural) =>
      '$value ${value == 1 ? singular : plural}';

  // "2 disponibilità, 1 prenotazione e 3 lezioni", omitting zero counts.
  String get said
  {
    final List<String> parts = [
      if (availabilities > 0) _counted(availabilities, 'disponibilità', 'disponibilità'),
      if (presences > 0) _counted(presences, 'prenotazione', 'prenotazioni'),
      if (lessons > 0) _counted(lessons, 'lezione', 'lezioni'),
    ];

    if (parts.length == 1)
    {
      return parts.single;
    }

    return '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}';
  }
}

// The server's refusal, carrying what the write would have cost.
class WriteWouldTakeAway implements Exception
{
  static const String code = 'write_would_take_away';

  final String message;
  final List<LostCalendar> lost;
  final LostHours hours;

  const WriteWouldTakeAway({
    required this.message,
    this.lost = const [],
    this.hours = const LostHours(),
  });

  factory WriteWouldTakeAway.fromJson(Map<String, dynamic> json)
  {
    return WriteWouldTakeAway(
      message: json['message'] as String? ?? 'La modifica eliminerebbe delle ore.',
      lost: [
        for (final row in (json['lost'] as List? ?? const []))
          LostCalendar.fromJson((row as Map).cast<String, dynamic>()),
      ],
      hours: LostHours.fromJson(
        ((json['hours'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
    );
  }

  @override
  String toString() => message;
}

// Asked once per save, however many writes it is made of.
class LossConfirmation
{
  final String confirmLabel;

  LossConfirmation({this.confirmLabel = 'SALVA COMUNQUE'});

  bool _confirmed = false;
  bool _declined = false;

  // True once the user answered no; the caller should stop.
  bool get declined => _declined;

  // Runs [write]; on a WriteWouldTakeAway refusal, asks the user and retries
  // with the answer. Any other exception propagates.
  Future<bool> run(
    BuildContext context,
    Future<void> Function(bool confirm) write,
  ) async
  {
    if (_declined)
    {
      return false;
    }

    try
    {
      await write(_confirmed);

      return true;
    }
    on WriteWouldTakeAway catch (refusal)
    {
      if (!context.mounted)
      {
        return false;
      }

      final agreed = await showLostCalendarsConfirmation(
        context: context,
        lost: refusal.lost,
        hours: refusal.hours,
        confirmLabel: confirmLabel,
      );

      if (agreed != true)
      {
        _declined = true;

        return false;
      }

      _confirmed = true;

      await write(true);

      return true;
    }
  }
}

// How many bands are named before the rest becomes a count.
const int _maxNamed = 4;

const double _buttonHeight = 52;
const double _buttonFontSize = 14;

Future<bool?> showLostCalendarsConfirmation({
  required BuildContext context,
  List<LostCalendar> lost = const [],
  LostHours hours = const LostHours(),
  String confirmLabel = 'SALVA COMUNQUE',
})
{
  final List<LostCalendar> ordered = [...lost]
    ..sort((a, b) => a.date.compareTo(b.date) != 0
        ? a.date.compareTo(b.date)
        : a.band.index.compareTo(b.band.index));

  final int hidden = ordered.length - ordered.take(_maxNamed).length;

  final bool anyWhole = ordered.any((row) => row.whole);
  final bool anyPartial = ordered.any((row) => !row.whole);

  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmLostCalendars',
    builder: (confirmContext) => AppDialogStack(
      eyebrow: ordered.isEmpty ? 'Ore utilizzate' : 'Calendario pubblicato',
      title: 'Confermi?',
      showClose: false,
      maxWidth: 520,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'ANNULLA',
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: () => Navigator.of(confirmContext).pop(false),
        ),
        primary: AppGradientButton(
          label: confirmLabel,
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: () => Navigator.of(confirmContext).pop(true),
        ),
      ),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ordered.isEmpty)
                Text(
                  '${hours.said} '
                  '${hours.isSingle ? 'non rientra' : 'non rientrano'} '
                  'nei nuovi orari.',
                  style: _prose,
                )
              else ...[
              Text(
                ordered.length == 1
                    ? 'Il calendario è già stato pubblicato per questa fascia oraria:'
                    : 'Il calendario è già stato pubblicato per queste fasce orarie:',
                style: _prose,
              ),
              const SizedBox(height: 10),
              for (final row in ordered.take(_maxNamed))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    row.said,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: AppTheme.trialOcean,
                    ),
                  ),
                ),
              if (hidden > 0)
                Text(
                  hidden == 1 ? 'e un\'altra' : 'e altre $hidden',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                [
                  if (anyWhole)
                    'Il calendario e le lezioni che docenti, studenti e genitori '
                        'hanno già ricevuto vengono eliminati.',
                  if (anyPartial)
                    'Le lezioni già pubblicate nella modalità che chiude vengono '
                        'eliminate e il calendario torna da pubblicare.',
                  if (hours.any)
                    'Il nuovo orario non permette di calendarizzare '
                        '${hours.said}.',
                ].join(' '),
                style: _prose,
              ),
              ],
              const SizedBox(height: 12),
              Text(
                // Italian gender agreement: calendar+lessons are masculine and
                // already declared deleted above; hours alone are feminine and
                // still need their own deletion sentence.
                ordered.isNotEmpty
                    ? 'Non potranno essere recuperati.'
                    : hours.isSingle
                        ? 'Verrà eliminata e non potrà essere recuperata.'
                        : 'Verranno eliminate e non potranno essere recuperate.',
                style: _prose,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final TextStyle _prose = GoogleFonts.plusJakartaSans(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  height: 1.45,
  color: AppTheme.trialInk,
);
