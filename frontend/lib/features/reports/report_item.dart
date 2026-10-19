import '../../core/utils/json_parsing.dart';

enum ReportKind
{
  appProblem('APP_PROBLEM'),
  personalData('PERSONAL_DATA'),
  missingSubject('MISSING_SUBJECT');

  final String code;

  const ReportKind(this.code);

  static ReportKind? of(Object? code)
  {
    for (final kind in values)
    {
      if (kind.code == code)
      {
        return kind;
      }
    }

    return null;
  }
}

class ReportCorrection
{
  final String field;
  final String value;

  const ReportCorrection(this.field, this.value);

  factory ReportCorrection.fromJson(Map<String, dynamic> json)
  {
    return ReportCorrection(json['field'] as String, json['value'] as String);
  }
}

// One report as its readers see it; [read] is per reader.
class ReportItem
{
  final int id;
  final ReportKind kind;
  final DateTime createdAt;
  final bool read;

  final String reporterTaxCode;
  final String reporterName;
  final String reporterEmail;
  final String? reporterRole;

  // Whose data is wrong, for personal data.
  final String? personTaxCode;
  final String? personName;

  // The discipline missing.
  final String? title;
  final String? description;

  final List<ReportCorrection> corrections;

  const ReportItem({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.read,
    required this.reporterTaxCode,
    required this.reporterName,
    required this.reporterEmail,
    this.reporterRole,
    this.personTaxCode,
    this.personName,
    this.title,
    this.description,
    this.corrections = const [],
  });

  factory ReportItem.fromJson(Map<String, dynamic> json)
  {
    return ReportItem(
      id: json['id'] as int,
      kind: ReportKind.of(json['kind'])!,
      createdAt: parseInstant(json['created_at'])!.toLocal(),
      read: json['read'] == true,
      reporterTaxCode: json['reporter_tax_code'] as String,
      reporterName: json['reporter_name'] as String,
      reporterEmail: json['reporter_email'] as String,
      reporterRole: json['reporter_role'] as String?,
      personTaxCode: json['person_tax_code'] as String?,
      personName: json['person_name'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      corrections: parseOptionalList(json['corrections'], ReportCorrection.fromJson) ?? const [],
    );
  }

  ReportItem asRead()
  {
    return ReportItem(
      id: id,
      kind: kind,
      createdAt: createdAt,
      read: true,
      reporterTaxCode: reporterTaxCode,
      reporterName: reporterName,
      reporterEmail: reporterEmail,
      reporterRole: reporterRole,
      personTaxCode: personTaxCode,
      personName: personName,
      title: title,
      description: description,
      corrections: corrections,
    );
  }
}
