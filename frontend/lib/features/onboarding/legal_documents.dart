import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/language/app_language.dart';
import '../../core/utils/rome_clock.dart';
import '../../core/utils/week_range.dart';

class LegalDocument
{
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  const LegalDocument({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });
}

// iubenda's own pages, opened on a tap; the app embeds none of their scripts.
// The English version has its own id on the same iubenda site.
List<LegalDocument> get kLegalDocuments => [
  LegalDocument(
    icon: Icons.gavel_rounded,
    title: tr('Termini e Condizioni', 'Terms and Conditions'),
    subtitle: tr("Le regole per l'uso dell'applicazione", 'The rules for using the app'),
    url: isEnglish
        ? 'https://www.iubenda.com/terms-and-conditions/90366927'
        : 'https://www.iubenda.com/termini-e-condizioni/84343803',
  ),
  LegalDocument(
    icon: Icons.privacy_tip_rounded,
    title: 'Privacy Policy',
    subtitle: tr('Quali dati trattiamo, perché e per quanto tempo', 'What data we handle, why and for how long'),
    url: isEnglish
        ? 'https://www.iubenda.com/privacy-policy/90366927'
        : 'https://www.iubenda.com/privacy-policy/84343803',
  ),
  LegalDocument(
    icon: Icons.cookie_rounded,
    title: 'Cookie Policy',
    subtitle: tr("Cosa l'applicazione salva sul tuo dispositivo", 'What the app saves on your device'),
    url: isEnglish
        ? 'https://www.iubenda.com/privacy-policy/90366927/cookie-policy'
        : 'https://www.iubenda.com/privacy-policy/84343803/cookie-policy',
  ),
];

String get kTermsDeclaration => tr(
    'Dichiaro di aver letto e di accettare i Termini e Condizioni, '
    'la Privacy Policy e la Cookie Policy.',
    'I declare that I have read and accept the Terms and Conditions, '
    'the Privacy Policy and the Cookie Policy.',
);

String get kTermsRefusal => tr('Per proseguire, conferma di aver letto e accettato i documenti.', 'To go on, confirm that you have read and accepted the documents.');

String get kTermsUpdateTitle => tr('Documenti aggiornati', 'Updated documents');

String get kTermsUpdateText => tr(
    "Abbiamo modificato i documenti che regolano l'uso dell'applicazione e spiegano come "
    'trattiamo i tuoi dati. Per proseguire, leggili e conferma di accettarli nuovamente.',
    'We have changed the documents that govern the use of the app and explain how '
    'we handle your data. To go on, read them and confirm that you accept them again.',
);

// The day the IT manager asked, on Rome's calendar: "28 ottobre 2026".
String termsUpdateEyebrow(DateTime updatedAt)
{
  final DateTime day = romeWallTime(updatedAt);

  return '${formatDayMonthFull(day)} ${day.year}';
}

// A new browser tab on the web, the in-app browser on phones.
Future<void> openLegalDocument(LegalDocument document)
{
  return launchUrl(
    Uri.parse(document.url),
    mode: LaunchMode.inAppBrowserView,
    webOnlyWindowName: '_blank',
  );
}
