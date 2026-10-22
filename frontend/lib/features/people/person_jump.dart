import 'package:flutter/foundation.dart';

// A pupil's Osservazioni asked for: a record not built yet takes it on start, a shown one listens.
abstract final class PersonJumps
{
  static String? _observations;

  // Bumped on every request.
  static final ValueNotifier<int> asked = ValueNotifier<int>(0);

  static void requestObservations(String taxCode)
  {
    _observations = taxCode;
    asked.value++;
  }

  // Spent only by the record it is for.
  static bool takeObservations(String taxCode)
  {
    if (_observations != taxCode)
    {
      return false;
    }

    _observations = null;

    return true;
  }
}

// One's own Osservazioni asked for: a page not built yet takes it on start, a shown one listens.
abstract final class OwnPageJumps
{
  static bool _observations = false;

  // Bumped on every request.
  static final ValueNotifier<int> asked = ValueNotifier<int>(0);

  static void requestObservations()
  {
    _observations = true;
    asked.value++;
  }

  static bool takeObservations()
  {
    final bool pending = _observations;
    _observations = false;

    return pending;
  }
}
