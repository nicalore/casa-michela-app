import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart' show formatDayMonthShort;
import '../../people/models/person_item.dart';
import 'dashboard_section_card.dart';

// The next two birthdays, wherever they fall: the one thing on the home page
// that asks for nothing, it is simply read. Two and no more, and no window
// either — a card that shows the next seven days is empty for most of the
// summer, and one that shows forty names is a list nobody reads on the way
// past.
//
// The reckoning is on day and month and not on the year: what is wanted is the
// next time the day comes round.

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

// The next time this person's day comes round, today included.
DateTime? _nextBirthday(DateTime? birth, DateTime today)
{
  if (birth == null)
  {
    return null;
  }

  for (final year in [today.year, today.year + 1])
  {
    // On years without a 29 February the birthday falls on the 28th: a
    // DateTime would roll it over to 1 March, and it would go unnoticed.
    final int day = birth.month == 2 && birth.day == 29 && !_isLeap(year)
        ? 28
        : birth.day;

    final DateTime when = DateTime(year, birth.month, day);

    if (!when.isBefore(today))
    {
      return when;
    }
  }

  return null;
}

// The first [limit] birthdays from today on, in the order they come.
List<DashboardBirthday> upcomingBirthdays(
  List<PersonItem> people, {
  int limit = 2,
  DateTime? from,
}) {
  final DateTime now = from ?? DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);

  final List<DashboardBirthday> found = [];

  for (final person in people)
  {
    final DateTime? when = _nextBirthday(person.birthDate, today);

    if (when == null)
    {
      continue;
    }

    found.add(DashboardBirthday(
      person: person,
      date: when,
      age: when.year - person.birthDate!.year,
    ));
  }

  // By name where two share a day, so the same two people come back in the same
  // order on every reading.
  found.sort((a, b)
  {
    final int day = a.date.compareTo(b.date);

    if (day != 0)
    {
      return day;
    }

    return '${a.person.lastName} ${a.person.firstName}'
        .toLowerCase()
        .compareTo('${b.person.lastName} ${b.person.firstName}'.toLowerCase());
  });

  return found.take(limit).toList();
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

  // How many names stand side by side on a row. Decided by the page, the only
  // one that knows how much room it gave this card: measuring it here would
  // want a LayoutBuilder, and a LayoutBuilder inside a row of equal-height
  // cards cannot answer how tall it would be.
  final int columns;

  // Passati alla card: quanto è alta almeno, se il contenuto riempie e se
  // l'intestazione è quella stretta.
  final double minHeight;
  final bool fill;
  final bool compact;

  const DashboardBirthdaysSection({
    super.key,
    required this.birthdays,
    this.isLoading = false,
    this.onTap,
    this.columns = 1,
    this.minHeight = 0,
    this.fill = false,
    this.compact = false,
  });

  // How wide the card has to be for two names to stand side by side: a face, a
  // name and a date twice over, with neither name ending in an ellipsis.
  // Measured on the narrowest column the home grid gives this card, which is
  // the one it has on the narrowest window the browser build draws.
  static const double twoInARowFrom = 380;

  static int columnsForWidth(double width) => width >= twoInARowFrom ? 2 : 1;

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      // The full title wraps in a card a third of the width, and a two-line
      // title raises the whole row of cards.
      eyebrow: 'Spegniamo le candeline',
      title: 'Compleanni',
      minHeight: minHeight,
      fill: fill,
      compact: compact,
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
              ),
            )
          : birthdays.isEmpty
              ? Text(
                  'Nessun compleanno in arrivo.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.trialMutedText,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  // Due righe soltanto, e la card è alta quanto la giornata le
                  // lascia: appoggiate in cima lascerebbero sotto di sé mezza
                  // card vuota, che si legge come una dimenticanza. Al centro
                  // l'aria sta intorno a loro.
                  mainAxisAlignment:
                      fill ? MainAxisAlignment.center : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var start = 0; start < birthdays.length; start += columns) ...[
                      if (start > 0) const SizedBox(height: 8),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < columns; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: start + i < birthdays.length
                                    ? _row(birthdays[start + i])
                                    : const SizedBox(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _row(DashboardBirthday birthday)
  {
    final bool tight = columns > 1;

    return _BirthdayRow(
      birthday: birthday,
      // The month is written out where the row has the width for it, and cut to
      // its three letters where two rows share it: the line under a name is
      // where the room runs out first, and "17 ago" is the same day as
      // "17 agosto" with none of the guessing an ellipsis leaves.
      when: birthday.isToday
          ? 'oggi'
          : (tight
              ? formatDayMonthShort(birthday.date)
              : '${birthday.date.day} ${_months[birthday.date.month - 1]}'),
      onTap: onTap == null ? null : () => onTap!(birthday.person),
      tight: tight,
    );
  }
}


class _BirthdayRow extends StatefulWidget
{
  final DashboardBirthday birthday;
  final String when;
  final VoidCallback? onTap;

  // Half a card's width instead of a whole one: the face is smaller and the
  // margins narrower, which is what it takes for a name to be read whole rather
  // than ended in an ellipsis.
  final bool tight;

  const _BirthdayRow({
    required this.birthday,
    required this.when,
    this.onTap,
    this.tight = false,
  });

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
          padding: widget.tight
              ? const EdgeInsets.fromLTRB(11, 9, 8, 9)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                width: widget.tight ? 30 : 34,
                height: widget.tight ? 30 : 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: widget.tight ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: widget.tight ? 10 : 12),
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
                        fontSize: widget.tight ? 14 : 15,
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
                        fontSize: widget.tight ? 12 : 12.5,
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
