import 'package:flutter/material.dart';

import 'settings_strings.dart';

// Served by GET /documents/{path}; the server names the downloaded file.
enum AssociationDocument
{
  statute('statute', kStatuteTitle, Icons.gavel_rounded),
  regulation('regulation', kRegulationTitle, Icons.menu_book_rounded),
  terms('terms', kTermsTitle, Icons.description_rounded),
  privacy('privacy', kPrivacyTitle, Icons.privacy_tip_rounded),
  cookies('cookies', kCookieTitle, Icons.cookie_rounded);

  final String path;
  final String title;
  final IconData icon;

  const AssociationDocument(this.path, this.title, this.icon);
}
