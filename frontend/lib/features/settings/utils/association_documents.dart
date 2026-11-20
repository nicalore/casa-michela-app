import 'package:flutter/material.dart';

import 'settings_strings.dart';

// Served by GET /documents/{path}; the server names the downloaded file.
enum AssociationDocument
{
  statute('statute', Icons.gavel_rounded),
  regulation('regulation', Icons.menu_book_rounded),
  terms('terms', Icons.description_rounded),
  privacy('privacy', Icons.privacy_tip_rounded),
  cookies('cookies', Icons.cookie_rounded);

  final String path;
  final IconData icon;

  const AssociationDocument(this.path, this.icon);

  String get title
  {
    return switch (this)
    {
      AssociationDocument.statute => kStatuteTitle,
      AssociationDocument.regulation => kRegulationTitle,
      AssociationDocument.terms => kTermsTitle,
      AssociationDocument.privacy => kPrivacyTitle,
      AssociationDocument.cookies => kCookieTitle,
    };
  }
}
