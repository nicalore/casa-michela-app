import 'package:flutter/foundation.dart';

// A section asked for from outside the menu, by a notification: the role first, if it differs.
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
}
