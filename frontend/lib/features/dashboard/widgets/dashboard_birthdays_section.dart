import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../people/models/person_item.dart';
import 'dashboard_section_card.dart';

// The birthdays of the next seven days: the one thing on the home page that
// asks for nothing, it is simply read. The reckoning is on day and month and not
// on the year.

class DashboardBirthday
{
  final PersonItem person;
  final DateTime date;
  final int age;

  const DashboardBirthday({
    required this.person,
    required this.date,
    required this.age,
  });

  bool get isToday
  {
    final DateTime now = DateTime.now();

    return date.day == now.day && date.month == now.month;
  }
}

// The birthdays falling from today through the next [days] days, in order.
List<DashboardBirthday> upcomingBirthdays(
  List<PersonItem> people, {
  int days = 7,
  DateTime? from,
}) {
  final DateTime today = DateTime(
    (from ?? DateTime.now()).year,
    (from ?? DateTime.now()).month,
    (from ?? DateTime.now()).day,
  );

  final List<DashboardBirthday> found = [];

  for (final person in people)
  {
    final DateTime? birth = person.birthDate;

    if (birth == null)
    {
      continue;
    }

    for (var offset = 0; offset <= days; offset++)
    {
      final DateTime day = today.add(Duration(days: offset));

      // On years without a 29 February the birthday falls on the 28th:
      // DateTime would roll it over to 1 March, and it would go unnoticed.
      final int birthDay = birth.month == 2 && birth.day == 29 && !_isLeap(day.year)
          ? 28
          : birth.day;

      if (day.month == birth.month && day.day == birthDay)
      {
        found.add(DashboardBirthday(
          person: person,
          date: day,
          age: day.year - birth.year,
        ));

        break;
      }
    }
  }

  found.sort((a, b) => a.date.compareTo(b.date));

  return found;
}

bool _isLeap(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

class DashboardBirthdaysSection extends StatelessWidget
{
  static const List<String> _months = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ];

  final List<DashboardBirthday> birthdays;
  final bool isLoading;
  final void Function(PersonItem person)? onTap;

  // How many rows fit in the card before the rest becomes a single line saying
  // how many are left. A home page is looked at, not scrolled: a list growing on
  // its own would stretch the whole row it sits in.
  final int maxRows;

  /// Passati alla card: quanto è alta almeno e se il contenuto riempie.
  final double minHeight;
  final bool fill;

  const DashboardBirthdaysSection({
    super.key,
    required this.birthdays,
    this.isLoading = false,
    this.onTap,
    this.maxRows = 4,
    this.minHeight = 0,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context)
  {
    // When there are too many, the last row goes to the count of those left
    // over, so the card is the same height whether there are four or forty.
    final int visible = birthdays.length > maxRows ? maxRows - 1 : birthdays.length;
    final List<DashboardBirthday> shown = birthdays.sublist(0, visible);
    final int hidden = birthdays.length - visible;

    return DashboardSectionCard(
      // The full title wraps in a card a third of the width, and a two-line
      // title raises the whole row of cards.
      eyebrow: 'Momenti di festa',
      title: 'Compleanni',
      minHeight: minHeight,
      fill: fill,
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
              ),
            )
          : birthdays.isEmpty
              ? Text(
                  'Nessun compleanno nei prossimi sette giorni.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.trialMutedText,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _BirthdayRow(
                        birthday: shown[i],
                        when: shown[i].isToday
                            ? 'oggi'
                            : '${shown[i].date.day} ${_months[shown[i].date.month - 1]}',
                        onTap: onTap == null ? null : () => onTap!(shown[i].person),
                      ),
                    ],
                    if (hidden > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 2),
                        child: Text(
                          hidden == 1
                              ? 'e un altro nei prossimi giorni'
                              : 'e altri $hidden nei prossimi giorni',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.trialMutedText,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _BirthdayRow extends StatefulWidget
{
  final DashboardBirthday birthday;
  final String when;
  final VoidCallback? onTap;

  const _BirthdayRow({required this.birthday, required this.when, this.onTap});

  @override
  State<_BirthdayRow> createState() => _BirthdayRowState();
}

class _BirthdayRowState extends State<_BirthdayRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final PersonItem person = widget.birthday.person;
    final String initials = '${person.firstName.isEmpty ? '' : person.firstName[0]}'
        '${person.lastName.isEmpty ? '' : person.lastName[0]}';

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.trialPaper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name above, date and age below: in a narrow column the two on
              // the same line take room from each other, and it is always the
              // name that loses.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${person.firstName} ${person.lastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    Text(
                      '${widget.birthday.age} anni · ${widget.when}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: widget.birthday.isToday
                            ? AppTheme.trialTealDeep
                            : AppTheme.trialMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
