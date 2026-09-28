import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../shared/widgets/band_time_range_slider.dart';
import '../../models/weekly_template_item.dart';

// One band as a wizard edits it: open between start and end, closed when both
// are null. The slider always sets both or neither.
class BandDraft
{
  TimeOfDay? start;
  TimeOfDay? end;

  BandDraft({this.start, this.end});

  bool get isOpen => start != null && end != null;

  bool matches(TimeOfDay? otherStart, TimeOfDay? otherEnd)
  {
    return _minutesOf(start) == _minutesOf(otherStart) && _minutesOf(end) == _minutesOf(otherEnd);
  }
}

typedef BandDrafts = Map<TimeBucket, BandDraft>;

int _minutesOf(TimeOfDay? time) => time == null ? -1 : time.hour * 60 + time.minute;

// Rows outside the day's bounds belong to no band and are left alone.
Map<TimeBucket, List<WeeklyTemplateItem>> standardRowsOf(
  List<WeeklyTemplateItem> templates,
  int weekday,
  String mode,
)
{
  final byBucket = {for (final bucket in TimeBucket.values) bucket: <WeeklyTemplateItem>[]};

  for (final row in templates.where((row) => row.weekday == weekday && row.mode == mode))
  {
    final bucket = bucketFor(row.startTime);

    if (bucket != null)
    {
      byBucket[bucket]!.add(row);
    }
  }

  for (final rows in byBucket.values)
  {
    rows.sort((a, b) => _minutesOf(a.startTime).compareTo(_minutesOf(b.startTime)));
  }

  return byBucket;
}

// The earliest row of a band is the one edited; the others are duplicates.
BandDrafts draftsFromRows(Map<TimeBucket, List<WeeklyTemplateItem>> rows)
{
  return {
    for (final bucket in TimeBucket.values)
      bucket: BandDraft(start: rows[bucket]!.firstOrNull?.startTime, end: rows[bucket]!.firstOrNull?.endTime),
  };
}

bool draftsMatchRows(BandDrafts drafts, Map<TimeBucket, List<WeeklyTemplateItem>> rows)
{
  return TimeBucket.values.every((bucket)
  {
    final row = rows[bucket]!.firstOrNull;

    return drafts[bucket]!.matches(row?.startTime, row?.endTime);
  });
}

// Two days with the same key open alike in every band.
String rowsSignature(Map<TimeBucket, List<WeeklyTemplateItem>> rows)
{
  return [
    for (final bucket in TimeBucket.values)
      rows[bucket]!.firstOrNull == null
          ? '-'
          : '${_minutesOf(rows[bucket]!.first.startTime)}-${_minutesOf(rows[bucket]!.first.endTime)}',
  ].join('|');
}

// Mattina, pomeriggio and sera, each open or closed.
class BandSliders extends StatelessWidget
{
  final BandDrafts drafts;
  final VoidCallback onChanged;

  const BandSliders({super.key, required this.drafts, required this.onChanged});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bucket in TimeBucket.values) ...[
          BandTimeRangeSlider(
            bucket: bucket,
            startTime: drafts[bucket]!.start,
            endTime: drafts[bucket]!.end,
            onChanged: (start, end)
            {
              drafts[bucket]!
                ..start = start
                ..end = end;
              onChanged();
            },
          ),
          if (bucket != TimeBucket.values.last)
            const Divider(height: 33, thickness: 1, color: AppTheme.trialLine),
        ],
      ],
    );
  }
}
