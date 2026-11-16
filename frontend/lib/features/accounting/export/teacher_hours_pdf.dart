import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../models/teacher_hours_items.dart';
import '../utils/accounting_strings.dart';
import 'accounting_pdf_look.dart';

typedef TeacherHoursPdfBand = ({TimeBucket band, TeacherHoursBand data});

const List<AccountingGroup> _groups = [
  AccountingGroup(parts: [(label: kTeacherColumn, width: 0)], flexible: true, leading: true),
  AccountingGroup(
    title: kWorkGroup,
    parts: [(label: kStartColumn, width: 48), (label: kEndColumn, width: 48), (label: kHoursColumn, width: 48)],
  ),
  AccountingGroup(
    title: kVolunteerGroup,
    parts: [(label: kStartColumn, width: 46), (label: kEndColumn, width: 46), (label: kHoursColumn, width: 46)],
  ),
  AccountingGroup(title: kPayGroup, parts: [(label: kGrossColumn, width: 63), (label: kNetColumn, width: 63)]),
];

// The whole day, each band with somebody in it on a page of its own.
Future<Uint8List> buildTeacherHoursPdf(DateTime day, List<TeacherHoursPdfBand> bands) async
{
  final AccountingPdfStyles styles = await accountingPdfStyles();
  final pw.Document document = accountingPdfDocument(styles, dailyPdfTab(day));
  final String exported = exportedAt(romeNow());

  for (final band in bands)
  {
    if (band.data.rows.isEmpty)
    {
      continue;
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: kAccountingPortrait,
        maxPages: 20,
        footer: (context) => accountingFooter(context, styles, dailyPdfFooter(day)),
        build: (context) => [
          accountingPdfHeader(
            styles,
            title: dailyPdfTitle(day),
            pills: [accountingPill(styles, kDailySummaryGroup), accountingPill(styles, kTeachersEntry)],
            meta: [exported],
          ),
          pw.SizedBox(height: 14),
          _bandBar(styles, band),
          pw.SizedBox(height: 6),
          accountingTable(_groups, [
            accountingHeadRow(styles, _groups),
            for (final row in band.data.rows) _row(styles, row),
            _totals(styles, band.data.rows),
          ], format: kAccountingPortrait),
        ],
      ),
    );
  }

  return document.save();
}

// No state: a band's page says only its name and how many teachers it holds.
pw.Widget _bandBar(AccountingPdfStyles styles, TeacherHoursPdfBand band)
{
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      // One line of text: name and count sit on the same baseline.
      pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '${bandLabel(band.band)}  ', style: styles.bandName),
            pw.TextSpan(text: teachersCount(band.data.rows.length), style: styles.bandCount),
          ],
        ),
      ),
      accountingModeLegend(styles),
    ],
  );
}

List<({String text, bool online})> _ends(List<HoursSpan> spans, {required bool online, required bool end})
{
  return [for (final span in spans) (text: clockOf(end ? span.end : span.start), online: online)];
}

pw.TableRow _row(AccountingPdfStyles styles, TeacherHoursRow row)
{
  final List<HoursSpan> work = row.absent ? const [] : row.work;
  final String? hours = row.absent || work.isEmpty ? null : formatMinutes(row.workedMinutes);

  // A volunteer's hours are all volunteering: they stand under it, nothing under work.
  final List<pw.Widget> worked = [
    accountingTimes(styles, _ends(work, online: row.isOnline, end: false)),
    accountingTimes(styles, _ends(work, online: row.isOnline, end: true)),
    accountingText(styles, hours, strong: true),
  ];

  final HoursSpan? volunteer = row.volunteer;
  final List<HoursSpan> given = volunteer == null ? const [] : [volunteer];

  final List<pw.Widget> volunteering = row.isVolunteer
      ? worked
      : [
          accountingTimes(styles, _ends(given, online: false, end: false)),
          accountingTimes(styles, _ends(given, online: false, end: true)),
          accountingText(styles, row.volunteerMinutes == 0 ? null : formatMinutes(row.volunteerMinutes), strong: true),
        ];

  final int? gross = row.absent ? null : row.gross;
  final int? net = row.absent ? null : row.net;

  return accountingRow(_groups, [
    [
      pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(row.fullName, style: styles.name),
          if (row.absent) ...[pw.SizedBox(height: 1.5), accountingTag(styles, kAbsentBadge)],
        ],
      ),
    ],
    row.isVolunteer ? [for (var i = 0; i < 3; i++) accountingDash(styles)] : worked,
    volunteering,
    [
      accountingText(styles, gross == null ? null : formatAmount(gross)),
      accountingText(styles, net == null ? null : formatAmount(net)),
    ],
  ]);
}

// Summed as on the page: a volunteer's hours count as volunteering, an absent teacher earns nothing.
pw.TableRow _totals(AccountingPdfStyles styles, List<TeacherHoursRow> rows)
{
  var worked = 0;
  var given = 0;
  var gross = 0;
  var net = 0;

  for (final row in rows)
  {
    if (row.isVolunteer)
    {
      given += row.workedMinutes;
    }
    else
    {
      worked += row.workedMinutes;
      given += row.volunteerMinutes;
    }

    if (!row.absent)
    {
      gross += row.gross ?? 0;
      net += row.net ?? 0;
    }
  }

  return accountingRow(
    _groups,
    [
      [accountingTotalLabel(styles)],
      [pw.SizedBox(), pw.SizedBox(), accountingText(styles, worked == 0 ? null : formatMinutes(worked), strong: true)],
      [pw.SizedBox(), pw.SizedBox(), accountingText(styles, given == 0 ? null : formatMinutes(given), strong: true)],
      [
        accountingText(styles, formatAmount(gross), strong: true),
        accountingText(styles, formatAmount(net), strong: true),
      ],
    ],
    rule: AccountingRule.total,
  );
}
