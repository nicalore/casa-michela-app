import '../../../shared/export/pdf_tab.dart';

import 'calendar_export_data.dart';
import 'calendar_pdf_document.dart';

export 'calendar_export_data.dart';

class CalendarExportTabs
{
  const CalendarExportTabs({required this.teachers, required this.students});

  final PdfTab? teachers;
  final PdfTab? students;

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

Future<void> writeCalendarPdfs({
  required CalendarExportData teachers,
  required CalendarExportData students,
  required CalendarExportTabs tabs,
}) async
{
  await presentPdfs(
    [
      for (final (data, tab) in [(teachers, tabs.teachers), (students, tabs.students)])
        (
          tab: tab,
          label: calendarPdfViewLabel(data),
          fileName: calendarPdfFileName(data),
          bytes: () => buildCalendarPdf(data),
        ),
    ],
    title: calendarPdfBandTitle(teachers),
  );
}

void failCalendarPdfTabs(CalendarExportTabs tabs, String message)
{
  tabs.teachers?.fail(message);
  tabs.students?.fail(message);
}
