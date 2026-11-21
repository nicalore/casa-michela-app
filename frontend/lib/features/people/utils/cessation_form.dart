import 'package:intl/intl.dart' show DateFormat;

import '../../../core/language/app_language.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/pdf_tab.dart';
import '../models/person_item.dart';

String _nameOf(PersonItem person) => '${person.firstName} ${person.lastName}';

// Call it straight from the click, before any await, or the browser blocks the tab.
PdfTab? openCessationFormTab(PersonItem person)
{
  final String name = _nameOf(person);

  return openPdfTab(title: tr('Modulo di cessazione · $name', 'Leaving form · $name'));
}

// True when the browser blocked the tab and the form was downloaded instead.
Future<bool> presentCessationForm(PersonItem person, PdfTab? tab, {required DateTime day})
{
  final String name = _nameOf(person);
  final String stamp = DateFormat('dd-MM-yyyy').format(day);

  return presentPdfs([
    (
      tab: tab,
      label: tr('Modulo di cessazione', 'Leaving form'),
      fileName: tr('Modulo di cessazione $name $stamp.pdf', 'Leaving form $name $stamp.pdf'),
      bytes: () => ApiService().fetchCessationForm(person.fiscalCode),
    ),
  ]);
}

String get kCessationFormBlocked => tr(
  'Il browser ha bloccato la scheda: il modulo è stato scaricato.',
  'The browser blocked the tab: the form was downloaded.',
);

String get kCessationFormFailed => tr('Non è stato possibile generare il modulo.', "Couldn't create the form.");
