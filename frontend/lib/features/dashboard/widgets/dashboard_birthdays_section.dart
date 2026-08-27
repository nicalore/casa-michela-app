import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart' show formatDayMonthShort;
import '../../people/models/person_item.dart';
import 'dashboard_section_card.dart';

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

DateTime? _nextBirthday(DateTime? birth, DateTime today)
{
  if (birth == null)
  {
    return null;
  }

  for (final year in [today.year, today.year + 1])
  {
    // Feb 29 falls on the 28th in non-leap years; DateTime would roll it over
    // to 1 March.
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

  // Tie-break by name for a stable order.
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

  // Decided by the page: measuring here would need a LayoutBuilder, which
  // cannot report a height inside a row of equal-height cards.
  final int columns;

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

  // Minimum card width for two names side by side without ellipsis.
  static const double twoInARowFrom = 380;

  static int columnsForWidth(double width) => width >= twoInARowFrom ? 2 : 1;

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
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
