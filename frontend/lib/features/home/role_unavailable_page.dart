import 'package:flutter/material.dart';

import '../../core/utils/role_label_mapper.dart';
import '../../services/api_service.dart';
import 'section_placeholder_page.dart';

// Landing page for roles whose area is not built yet.
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
