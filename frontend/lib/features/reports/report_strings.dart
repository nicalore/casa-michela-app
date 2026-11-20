import '../../core/language/app_language.dart';
import 'report_item.dart';

String get kReportsEntry => tr('Segnalazioni', 'Reports');
String get kReportsTitle => tr('Segnalazioni', 'Reports');
String get kReportsEyebrow => tr('Segnalazioni', 'Reports');

String get kAllKinds => tr('Tutti i tipi', 'All types');
String get kKindPrefix => tr('Tipo', 'Type');
String get kKindSheetTitle => tr('Tipo di segnalazione', 'Report type');
String get kNoReports => tr('Nessuna segnalazione da risolvere', 'No reports to resolve');

String get kDateLabel => tr('Data', 'Date');
String get kSentByLabel => tr('Inviata da', 'Sent by');
String get kRoleLabel => tr('Ruolo', 'Role');
String get kEmailLabel => tr('Email', 'Email');
String get kTaxCodeLabel => tr('Codice fiscale', 'Tax code');
String get kCorrectionsHeading => tr('Correzioni richieste', 'Corrections requested');

// Desktop buttons are written in capitals, the phone's capitalise themselves.
String get kResolveButton => tr('SEGNA COME RISOLTA', 'MARK AS RESOLVED');
String get kResolveLabel => tr('Segna come risolta', 'Mark as resolved');
String get kResolved => tr('Segnalazione risolta', 'Report resolved');

extension ReportKindLabels on ReportKind
{
  String get label => switch (this)
  {
    ReportKind.appProblem => tr("Problema nell'app", 'App problem'),
    ReportKind.personalData => tr('Errore nei dati', 'Data error'),
    ReportKind.missingSubject => tr('Disciplina mancante', 'Missing discipline'),
  };

  String get plural => switch (this)
  {
    ReportKind.appProblem => tr("Problemi nell'app", 'App problems'),
    ReportKind.personalData => tr('Errori nei dati', 'Data errors'),
    ReportKind.missingSubject => tr('Discipline mancanti', 'Missing disciplines'),
  };
}

String reportCountLabel(int count) => count == 1
    ? tr('1 segnalazione da risolvere', '1 report to resolve')
    : tr('$count segnalazioni da risolvere', '$count reports to resolve');

// The phone's shorter line.
String reportShortCountLabel(int count) => tr('$count da risolvere', '$count to resolve');

// A problem has no title of its own: its sender names it.
String reportTitle(ReportItem report) => switch (report.kind)
{
  ReportKind.appProblem => tr('Segnalazione di ${report.reporterName}', 'Report from ${report.reporterName}'),
  ReportKind.personalData => tr(
    'Dati di ${report.personName ?? report.reporterName}',
    "${report.personName ?? report.reporterName}'s data",
  ),
  ReportKind.missingSubject => report.title ?? '',
};

String reportCorrectionsPreview(ReportItem report)
{
  final List<String> fields = [
    for (final correction in report.corrections)
      correction.field.isEmpty ? correction.field : correction.field[0].toLowerCase() + correction.field.substring(1),
  ];

  return tr('Da correggere: ${fields.join(', ')}', 'To correct: ${fields.join(', ')}');
}

String resolveNote(String who) => tr(
  '$who riceverà un’email quando indicherai la segnalazione come risolta.',
  '$who will receive an email when you mark the report as resolved.',
);
