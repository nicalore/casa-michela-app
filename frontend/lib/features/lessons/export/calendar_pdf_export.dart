import 'calendar_export_data.dart';
import 'calendar_pdf_document.dart';
import 'calendar_pdf_tab.dart';

export 'calendar_export_data.dart';

enum CalendarExportOutcome
{
  opened,

  downloaded,

  blocked,
}

class CalendarExportTabs
{
  const CalendarExportTabs({required this.teachers, required this.students});

  final CalendarPdfTab? teachers;
  final CalendarPdfTab? students;

  bool get isEmpty => teachers == null && students == null;
}

CalendarExportTabs openCalendarPdfTabs({
  required CalendarExportData teachers,
  required CalendarExportData students,
})
{
  return CalendarExportTabs(
    teachers: openPdfTab(title: calendarPdfTitle(teachers)),
    students: openPdfTab(title: calendarPdfTitle(students)),
  );
}

Future<CalendarExportOutcome> writeCalendarPdfs({
  required CalendarExportData teachers,
  required CalendarExportData students,
  required CalendarExportTabs tabs,
}) async
{
  var handedOver = false;

  for (final (data, tab) in [(teachers, tabs.teachers), (students, tabs.students)])
  {
    final bytes = await buildCalendarPdf(data);
    final fileName = calendarPdfFileName(data);

    if (tab != null)
    {
      tab.present(bytes, fileName: fileName);

      continue;
    }

    handedOver = downloadPdf(bytes, fileName: fileName) || handedOver;
  }

  return handedOver ? CalendarExportOutcome.downloaded : CalendarExportOutcome.opened;
}

void failCalendarPdfTabs(CalendarExportTabs tabs, String message)
{
  tabs.teachers?.fail(message);
  tabs.students?.fail(message);
}
