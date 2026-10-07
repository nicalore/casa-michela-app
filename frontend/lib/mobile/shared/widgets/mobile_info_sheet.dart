import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mobile_sheet.dart';

const String _seenPrefix = 'mobile_section_intro';

const double _paragraphGap = 10;

Future<void> showMobileInfoSheet({
  required BuildContext context,
  required String title,
  required List<String> paragraphs,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: 'Informazioni',
      title: title,
      body: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          SizedBox(height: i == 0 ? 12 : _paragraphGap),
          MobileSheetText(paragraphs[i]),
        ],
        const SizedBox(height: 8),
      ],
    ),
  );
}

// Once per person and section, stored per install.
Future<void> showMobileInfoSheetOnce({
  required BuildContext context,
  required String taxCode,
  required String slug,
  required String title,
  required List<String> paragraphs,
}) async
{
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = '$_seenPrefix/$taxCode/$slug';

  if (prefs.getBool(key) ?? false)
  {
    return;
  }

  await prefs.setBool(key, true);

  if (!context.mounted)
  {
    return;
  }

  await showMobileInfoSheet(context: context, title: title, paragraphs: paragraphs);
}
