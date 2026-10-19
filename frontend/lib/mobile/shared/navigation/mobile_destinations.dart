import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/reports/report_strings.dart';
import '../../../routing/role_sections.dart';

const String kMobileHomeSlug = 'home';

const String kMobileOwnPageSlug = 'profile';
const String kMobileSettingsSlug = 'settings';
const String kMobileReportsSlug = 'reports';

// A role's sections come from role_sections.dart, so the menu matches the desktop bar.
const Map<String, IconData> _sectionIcons = <String, IconData>{
  'subjects': Icons.menu_book_rounded,
  'availability': Icons.event_available_rounded,
  'calendar': Icons.calendar_month_rounded,
  'compensation': Icons.payments_rounded,
  'association': Icons.groups_rounded,
  'bookings': Icons.bookmark_added_rounded,
  'payments': Icons.receipt_long_rounded,
  'children': Icons.family_restroom_rounded,
};

class MobileDestination
{
  final String slug;
  final String label;
  final IconData icon;

  // Listed but not offered, as on the desktop bar.
  final bool available;

  // Things waiting there, counted beside the entry.
  final ValueListenable<int>? count;

  const MobileDestination({
    required this.slug,
    required this.label,
    required this.icon,
    required this.available,
    this.count,
  });
}

List<MobileDestination> mobileDestinationsFor(String role, {required bool hasParentalResponsibility})
{
  return [
    const MobileDestination(
      slug: kMobileHomeSlug,
      label: 'Home',
      icon: Icons.home_rounded,
      available: true,
    ),
    for (final section in sectionsFor(role, hasParentalResponsibility: hasParentalResponsibility))
      MobileDestination(
        slug: section.slug,
        label: section.label,
        icon: _sectionIcons[section.slug] ?? Icons.grid_view_rounded,
        available: section.available,
      ),
  ];
}

// reports: the unread count, for those who receive reports.
List<MobileDestination> mobileUserDestinationsFor(String firstName, {ValueListenable<int>? reports})
{
  return [
    MobileDestination(
      slug: kMobileOwnPageSlug,
      label: firstName,
      icon: Icons.person_rounded,
      available: true,
    ),
    const MobileDestination(
      slug: kMobileSettingsSlug,
      label: 'Impostazioni',
      icon: Icons.settings_rounded,
      available: true,
    ),
    if (reports != null)
      MobileDestination(
        slug: kMobileReportsSlug,
        label: kReportsEntry,
        icon: Icons.flag_rounded,
        available: true,
        count: reports,
      ),
  ];
}
