import 'package:flutter/material.dart';

import '../../core/utils/role_label_mapper.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_load_failed.dart';
import '../auth/models/me_response.dart';
import 'section_placeholder_page.dart';

// Landing page for roles whose area is not built yet, and for a kept session whose identity is unread.
class RoleUnavailablePage extends StatelessWidget
{
  const RoleUnavailablePage({super.key});

  @override
  Widget build(BuildContext context)
  {
    final ApiService api = ApiService();

    return ValueListenableBuilder<MeResponse?>(
      valueListenable: api.identity,
      builder: (context, user, _)
      {
        if (user == null)
        {
          return ValueListenableBuilder<Object?>(
            valueListenable: api.identityFailure,
            builder: (context, failure, _) => SectionPlaceholderPage(
              currentRoute: '',
              showNavigation: false,
              content: AppLoadFailedRoom(
                error: failure,
                message: 'Non è stato possibile caricare i tuoi dati.',
                onRetry: api.retryIdentity,
              ),
            ),
          );
        }

        final String role = user.activeRole;

        return SectionPlaceholderPage(
          currentRoute: '',
          title: RoleLabelMapper.toLabel(role, feminine: user.gender == 'F'),
          description: "L'area dedicata al tuo ruolo non è ancora disponibile.",
          showNavigation: false,
        );
      },
    );
  }
}
