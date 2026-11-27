import 'package:flutter/material.dart';

import '../core/language/app_language.dart';
import '../features/people/utils/compensation_strings.dart' show kWalletSection;

// An unavailable section is still listed on the bar, muted and unclickable.
class RoleSection
{
  final String slug;
  final String? _label;

  final bool available;

  const RoleSection(this.slug, String label, {this.available = false}) : _label = label;

  // A section of the bar: its name follows the language.
  const RoleSection.named(this.slug, {this.available = false}) : _label = null;

  String get label
  {
    return _label ?? switch (slug)
    {
      'calendar' => tr('Calendario', 'Calendar'),
      'bookings' => tr('Prenotazioni', 'Bookings'),
      'payments' => tr('Pagamenti', 'Payments'),
      'association' => tr('Associazione', 'Association'),
      'subjects' => tr('Discipline', 'Disciplines'),
      'availability' => tr('Disponibilità', 'Availability'),
      'compensation' => kWalletSection,
      'children' => tr('Figli', 'Children'),
      'students' => tr('Studenti', 'Students'),
      _ => slug,
    };
  }
}

const RoleSection _calendar = RoleSection.named('calendar', available: true);
const RoleSection _bookings = RoleSection.named('bookings', available: true);
const RoleSection _payments = RoleSection.named('payments', available: true);
const RoleSection _association = RoleSection.named('association', available: true);

const Map<String, List<RoleSection>> _sectionsByRole = {
  'TEACHER': [
    RoleSection.named('subjects', available: true),
    RoleSection.named('availability', available: true),
    _calendar,
    // Their pay and their fees.
    RoleSection.named('compensation', available: true),
    _association,
  ],
  'PARENT': [
    _bookings,
    _calendar,
    _payments,
    RoleSection.named('children', available: true),
    _association,
  ],
  'STUDENT': [
    _bookings,
    _calendar,
    _payments,
    _association,
  ],
  'PSYCHOLOGIST': [
    RoleSection.named('students', available: true),
  ],
};

// Shared by the mobile menu and the desktop bar's menus.
const Map<String, IconData> kSectionIcons = <String, IconData>{
  'subjects': Icons.menu_book_rounded,
  'availability': Icons.event_available_rounded,
  'calendar': Icons.calendar_month_rounded,
  'compensation': Icons.account_balance_wallet_rounded,
  'association': Icons.groups_rounded,
  'bookings': Icons.bookmark_added_rounded,
  'payments': Icons.receipt_long_rounded,
  'children': Icons.family_restroom_rounded,
};

List<RoleSection> allSectionsOf(String role)
{
  return _sectionsByRole[role] ?? const [];
}

// A pupil somebody answers for does not see payments.
List<RoleSection> sectionsFor(String role, {required bool hasParentalResponsibility})
{
  return [
    for (final section in _sectionsByRole[role] ?? const <RoleSection>[])
      if (!(role == 'STUDENT' && hasParentalResponsibility && section == _payments))
        section,
  ];
}
