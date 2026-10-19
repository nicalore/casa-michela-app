import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/time_bucket.dart';
import '../../../lessons/utils/opening_window.dart';
import '../../models/opening_day_item.dart';
import '../../models/weekly_template_item.dart';

typedef HoursSpan = (TimeOfDay, TimeOfDay);

const String kPastDaysError = 'Non si possono cambiare gli orari dei giorni passati.';

String begunHoursError(String mode, TimeBucket band) =>
    'Gli orari ${modeLabel(mode).toLowerCase()} ${ofBandLabel(band)} di oggi sono già iniziati: '
        'non si possono più cambiare.';

List<HoursSpan> hoursOfRows(Iterable<OpeningDayItem> rows, String mode)
{
  return [
    for (final row in rows)
      if (row.mode == mode && row.startTime != null && row.endTime != null) (row.startTime!, row.endTime!),
  ];
}

// What restoring the standard writes on that weekday.
List<HoursSpan> standardHoursOn(List<WeeklyTemplateItem> templates, int weekday, String mode)
{
  return [
    for (final row in templates)
      if (row.weekday == weekday && row.mode == mode) (row.startTime, row.endTime),
  ];
}

Set<(int, int)> _minutesIn(Iterable<HoursSpan> hours, TimeBucket band)
{
  return {
    for (final (start, end) in hours)
      if (bucketFor(start) == band) (minutesOfTimeOfDay(start), minutesOfTimeOfDay(end)),
  };
}

// Mirrors app/services/started_hours.py: the first band whose hours, old or new, have begun and would change.
TimeBucket? begunBandChanged(DateTime day, Iterable<HoursSpan> current, Iterable<HoursSpan> next, DateTime now)
{
  for (final band in TimeBucket.values)
  {
    final was = _minutesIn(current, band);
    final becomes = _minutesIn(next, band);

    if (setEquals(was, becomes))
    {
      continue;
    }

    final starts = {...was, ...becomes}.map((span) => span.$1).reduce(math.min);

    if (!DateTime(day.year, day.month, day.day, starts ~/ 60, starts % 60).isAfter(now))
    {
      return band;
    }
  }

  return null;
}
