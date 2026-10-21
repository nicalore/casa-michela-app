import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
const List<LegalDocument> kLegalDocuments = [
  LegalDocument(
    icon: Icons.gavel_rounded,
    title: 'Termini e Condizioni',
    subtitle: "Le regole per l'uso dell'applicazione",
    url: 'https://www.iubenda.com/termini-e-condizioni/84343803',
  ),
  LegalDocument(
    icon: Icons.privacy_tip_rounded,
    title: 'Privacy Policy',
    subtitle: 'Quali dati trattiamo, perché e per quanto tempo',
    url: 'https://www.iubenda.com/privacy-policy/84343803',
  ),
  LegalDocument(
    icon: Icons.cookie_rounded,
    title: 'Cookie Policy',
    subtitle: "Cosa l'applicazione salva sul tuo dispositivo",
    url: 'https://www.iubenda.com/privacy-policy/84343803/cookie-policy',
  ),
];

const String kTermsDeclaration = 'Dichiaro di aver letto e di accettare i Termini e Condizioni, '
    'la Privacy Policy e la Cookie Policy.';

const String kTermsRefusal = 'Per proseguire, conferma di aver letto e accettato i documenti.';

// A new browser tab on the web, the in-app browser on phones.
Future<void> openLegalDocument(LegalDocument document)
{
  return launchUrl(
    Uri.parse(document.url),
    mode: LaunchMode.inAppBrowserView,
    webOnlyWindowName: '_blank',
  );
}
