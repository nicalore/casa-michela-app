// An unavailable section is still listed on the bar, muted and unclickable.
class RoleSection
{
  final String slug;
  final String label;

  final bool available;

  const RoleSection(this.slug, this.label, {this.available = false});
}

const RoleSection _calendar = RoleSection('calendar', 'Calendario', available: true);
const RoleSection _bookings = RoleSection('bookings', 'Prenotazioni', available: true);
const RoleSection _payments = RoleSection('payments', 'Pagamenti');
const RoleSection _association = RoleSection('association', 'Associazione', available: true);

const Map<String, List<RoleSection>> _sectionsByRole = {
  'TEACHER': [
    RoleSection('subjects', 'Discipline', available: true),
    RoleSection('availability', 'Disponibilità', available: true),
    _calendar,
    RoleSection('compensation', 'Compensi'),
    _association,
  ],
  'PARENT': [
    _bookings,
    _calendar,
    _payments,
    RoleSection('children', 'Figli', available: true),
    _association,
  ],
  'STUDENT': [
    _bookings,
    _calendar,
    _payments,
    _association,
  ],
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
