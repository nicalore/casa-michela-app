import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'app_primary_button.dart';

const String _fontFamily = 'Plus Jakarta Sans';

class NotFoundPage extends StatelessWidget
{
  final String? requestedLocation;

  const NotFoundPage({super.key, this.requestedLocation});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 28),
                const Text(
                  'Errore 404',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "L'indirizzo che hai digitato non corrisponde a nessuna pagina disponibile.",
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 36),
                AppPrimaryButton(
                  label: 'TORNA ALLA HOME',
                  width: 200,
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}