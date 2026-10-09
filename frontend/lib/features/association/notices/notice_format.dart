import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import 'notice_strings.dart';

// Mirrors MAX_FILES_BYTES in backend/app/services/notices.py.
const int kNoticeFilesMaxBytes = 15 * 1024 * 1024;

const String kNoticeFilesLimitLabel = '15 MB';

const int _kilobyte = 1024;
const int _megabyte = 1024 * 1024;

String noticeDay(DateTime instant) => '${formatDayMonthFull(instant)} ${instant.year}';

String noticeHour(DateTime instant) => formatTimeOfDayShort(TimeOfDay.fromDateTime(instant));

String noticeSent(DateTime instant) => noticeSentLabel(noticeDay(instant), noticeHour(instant));

// "5 ott", with the year only when it is not the current one.
String noticeShortDay(DateTime instant, {required DateTime today}) =>
    instant.year == today.year ? formatDayMonthShort(instant) : '${formatDayMonthShort(instant)} ${instant.year}';

// "5 ottobre", with the year only when it is not the current one.
String noticeLongDay(DateTime instant, {required DateTime today}) =>
    instant.year == today.year ? formatDayMonthFull(instant) : '${formatDayMonthFull(instant)} ${instant.year}';

// With the weekday, for the details.
String noticeSentLong(DateTime instant) =>
    noticeSentLabel('${formatWeekdayColumnLabel(instant)} ${instant.year}', noticeHour(instant));

// Decimal comma, one figure after it.
String fileSizeLabel(int bytes)
{
  if (bytes >= _megabyte)
  {
    return '${(bytes / _megabyte).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  return '${(bytes / _kilobyte).ceil()} KB';
}

// The badge a file is shown with, from its extension.
enum NoticeFileKind
{
  pdf(Icons.picture_as_pdf_rounded, AppTheme.trialDanger),
  image(Icons.image_rounded, AppTheme.trialViolet),
  sheet(Icons.table_chart_rounded, AppTheme.trialLagoon),
  other(Icons.insert_drive_file_rounded, AppTheme.trialTealDeep);

  final IconData icon;
  final Color color;

  const NoticeFileKind(this.icon, this.color);

  static NoticeFileKind of(String fileName)
  {
    final String extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    return switch (extension)
    {
      'pdf' => pdf,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'heic' => image,
      'xls' || 'xlsx' || 'csv' || 'ods' => sheet,
      _ => other,
    };
  }
}
