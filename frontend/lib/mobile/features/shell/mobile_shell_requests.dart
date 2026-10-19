import 'package:flutter/foundation.dart';

// A section requested outside the menu, by a notification: the role first, if it differs.
abstract final class MobileShellRequests
{
  static final ValueNotifier<({String role, String slug})?> section = ValueNotifier(null);

  static void open(String role, String slug) => section.value = (role: role, slug: slug);

  static ({String role, String slug})? take()
  {
    final ({String role, String slug})? request = section.value;
    section.value = null;

    return request;
  }

  // A report, over whatever page is shown.
  static final ValueNotifier<int?> report = ValueNotifier(null);

  static void openReport(int id) => report.value = id;

  static int? takeReport()
  {
    final int? id = report.value;
    report.value = null;

    return id;
  }
}
