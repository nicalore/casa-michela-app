import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/language/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/widgets/auth_pill_page.dart';
import 'app_dialog_stack.dart';
import 'app_gradient_button.dart';

class NotFoundPage extends StatelessWidget
{
  final String? requestedLocation;

  const NotFoundPage({super.key, this.requestedLocation});

  @override
  Widget build(BuildContext context)
  {
    return AuthPillPage(
      eyebrow: tr('Errore 404', 'Error 404'),
      title: tr('Pagina non trovata', 'Page not found'),
      maxWidth: 560,
      footer: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AppGradientButton(
          label: tr('TORNA ALLA HOME', 'BACK TO HOME'),
          icon: Icons.home_rounded,
          height: 52,
          fontSize: 14,
          onPressed: () => context.go('/'),
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  "L'indirizzo che hai digitato non corrisponde a nessuna pagina "
                  'disponibile.',
                  "The address you typed doesn't match any available page.",
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: AppTheme.trialMutedText,
                ),
              ),
              if (requestedLocation != null) ...[
                const SizedBox(height: 14),
                Text(
                  requestedLocation!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialTealDeepText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
