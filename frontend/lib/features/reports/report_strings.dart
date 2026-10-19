import 'report_item.dart';

const String kReportsEntry = 'Segnalazioni';
const String kReportsTitle = 'Segnalazioni';
const String kReportsEyebrow = 'Segnalazioni';

const String kAllKinds = 'Tutti i tipi';
const String kKindPrefix = 'Tipo';
const String kKindSheetTitle = 'Tipo di segnalazione';
const String kNoReports = 'Nessuna segnalazione da risolvere';

const String kDateLabel = 'Data';
const String kSentByLabel = 'Inviata da';
const String kRoleLabel = 'Ruolo';
const String kEmailLabel = 'Email';
const String kTaxCodeLabel = 'Codice fiscale';
const String kCorrectionsHeading = 'Correzioni richieste';

// Desktop buttons are written in capitals, the phone's capitalise themselves.
const String kResolveButton = 'SEGNA COME RISOLTA';
const String kResolveLabel = 'Segna come risolta';
const String kResolved = 'Segnalazione risolta';

extension ReportKindLabels on ReportKind
{
  String get label => switch (this)
  {
    ReportKind.appProblem => "Problema nell'app",
    ReportKind.personalData => 'Errore nei dati',
    ReportKind.missingSubject => 'Disciplina mancante',
  };

  String get plural => switch (this)
  {
    ReportKind.appProblem => "Problemi nell'app",
    ReportKind.personalData => 'Errori nei dati',
    ReportKind.missingSubject => 'Discipline mancanti',
  };
}

String reportCountLabel(int count) =>
    count == 1 ? '1 segnalazione da risolvere' : '$count segnalazioni da risolvere';

// The phone's shorter line.
String reportShortCountLabel(int count) => '$count da risolvere';

// A problem has no title of its own: its sender names it.
String reportTitle(ReportItem report) => switch (report.kind)
{
  ReportKind.appProblem => 'Segnalazione di ${report.reporterName}',
  ReportKind.personalData => 'Dati di ${report.personName ?? report.reporterName}',
  ReportKind.missingSubject => report.title ?? '',
};

String reportCorrectionsPreview(ReportItem report)
{
  final List<String> fields = [
    for (final correction in report.corrections)
      correction.field.isEmpty ? correction.field : correction.field[0].toLowerCase() + correction.field.substring(1),
  ];

  return 'Da correggere: ${fields.join(', ')}';
}

String resolveNote(String who) => '$who riceverà un’email quando indicherai la segnalazione come risolta.';
