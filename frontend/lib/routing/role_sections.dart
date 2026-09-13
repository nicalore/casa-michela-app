// The sections a role's bar leads to, in reading order. Each is a page of
// its own under the role's home; the router and the bar both read this.
class RoleSection
{
  final String slug;

  // Null for the person's own page, which the bar names after them.
  final String? label;

  const RoleSection(this.slug, this.label);

  bool get isOwnPage => label == null;
}

const RoleSection ownPage = RoleSection('profile', null);

const RoleSection _calendar = RoleSection('calendar', 'Calendario');
const RoleSection _bookings = RoleSection('bookings', 'Prenotazioni');
const RoleSection _payments = RoleSection('payments', 'Pagamenti');
const RoleSection _association = RoleSection('association', 'Associazione');
const RoleSection _settings = RoleSection('settings', 'Impostazioni');

const Map<String, List<RoleSection>> _sectionsByRole = {
  'TEACHER': [
    RoleSection('availability', 'Disponibilità'),
    _calendar,
    RoleSection('compensation', 'Compensi'),
    _association,
    ownPage,
    _settings,
  ],
  'PARENT': [
    _bookings,
    _calendar,
    _payments,
    RoleSection('children', 'Figli'),
    _association,
    ownPage,
    _settings,
  ],
  'STUDENT': [
    _bookings,
    _calendar,
    _payments,
    _association,
    ownPage,
    _settings,
  ],
};

// Every section the role can be routed to, whoever holds it.
List<RoleSection> allSectionsOf(String role) => _sectionsByRole[role] ?? const [];

// The sections this person's bar shows: a pupil somebody answers for is not
// the one who pays.
List<RoleSection> sectionsFor(String role, {required bool hasParentalResponsibility})
{
  return [
    for (final section in allSectionsOf(role))
      if (!(role == 'STUDENT' && hasParentalResponsibility && section == _payments))
        section,
  ];
}
