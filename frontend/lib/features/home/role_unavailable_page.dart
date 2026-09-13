import 'package:flutter/material.dart';

import '../../core/utils/role_label_mapper.dart';
import '../../services/api_service.dart';
import 'section_placeholder_page.dart';

// Where psychologists and course participants land: their role is recognised,
// their area is not built yet. The user menu still opens, so they can log out
// and, if they hold another role, switch to it.
class RoleUnavailablePage extends StatelessWidget
{
  const RoleUnavailablePage({super.key});

  @override
  Widget build(BuildContext context)
  {
    final String? role = ApiService().lastKnownIdentity?.activeRole;

    return SectionPlaceholderPage(
      currentRoute: '',
      eyebrow: 'Area personale',
      title: role != null ? RoleLabelMapper.toLabel(role) : 'Il tuo ruolo',
      description: "L'area dedicata al tuo ruolo non è ancora disponibile.",
      showNavigation: false,
    );
  }
}
