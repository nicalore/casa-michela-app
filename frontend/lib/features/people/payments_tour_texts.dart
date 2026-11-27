import '../../core/language/app_language.dart';
import 'models/student_payments_item.dart';
import 'utils/payments_strings.dart' show kPaymentsSection;

// The Pagamenti tours' sentences, his wording, shared by the computer and the phone.

String get kPaymentsTourTitle => kPaymentsSection;

bool _daughter(String? gender) => gender == 'F';

// «tuo figlio» / «tua figlia»: the child shown.
String _yours(String? gender) => _daughter(gender) ? tr('tua figlia', 'your daughter') : tr('tuo figlio', 'your son');

String _yoursOf(String? gender) =>
    _daughter(gender) ? tr('di tua figlia', "your daughter's") : tr('di tuo figlio', "your son's");

String get kPaymentsTourIntro => tr(
  "In questa pagina puoi consultare la tua situazione economica verso l'Associazione ed effettuare pagamenti.",
  'On this page you can see where you stand with the Association and make payments.',
);

// [genders]: every child's.
String paymentsTourChildren(List<String?> genders)
{
  final bool daughters = genders.isNotEmpty && genders.every(_daughter);

  return daughters
      ? tr(
          'Da qui puoi selezionare la figlia di cui vuoi vedere i pagamenti.',
          'From here you can choose the daughter whose payments you want to see.',
        )
      : tr(
          'Da qui puoi selezionare il figlio di cui vuoi vedere i pagamenti.',
          'From here you can choose the child whose payments you want to see.',
        );
}

// [self]: a pupil reading their own; else [gender] is the child shown.
String paymentsTourTariff({required bool self, String? gender})
{
  if (self)
  {
    return tr('Qui trovi la tua tariffa attuale.', 'Here you find your current rate.');
  }

  return isEnglish
      ? 'Here you find ${_yoursOf(gender)} current rate.'
      : 'Qui trovi la tariffa attuale ${_yoursOf(gender)}.';
}

String paymentsTourStatus({required bool self, String? gender})
{
  if (self)
  {
    return tr(
      'Qui puoi vedere se sei in regola con i pagamenti o se hai qualcosa da pagare.',
      'Here you can see whether your payments are up to date or you have something to pay.',
    );
  }

  return isEnglish
      ? "Here you can see whether ${_yoursOf(gender)} payments are up to date or there is something to pay."
      : 'Qui puoi vedere se ${_yours(gender)} è in regola con i pagamenti o se c\'è qualcosa da pagare.';
}

// What «PAGA» does for the tariff of the person shown; fees alone for a member parent's own.
String paymentsTourPay(StudentTariffItem? tariff)
{
  if (tariff == null)
  {
    return tr('Con «PAGA» puoi saldare eventuali cifre non ancora pagate.', 'With “PAY” you can pay any amounts not paid yet.');
  }

  if (tariff.isPackage)
  {
    return tr(
      'Con «PAGA» puoi saldare eventuali cifre non ancora pagate o rinnovare il pacchetto.',
      'With “PAY” you can pay any amounts not paid yet or renew the package.',
    );
  }

  if (tariff.isMonthly)
  {
    return tr(
      'Con «PAGA» puoi saldare eventuali cifre non ancora pagate o rinnovare la quota mensile.',
      'With “PAY” you can pay any amounts not paid yet or renew the monthly fee.',
    );
  }

  return tr(
    'Con «PAGA» puoi saldare eventuali cifre non ancora pagate o pagare ore in anticipo.',
    'With “PAY” you can pay any amounts not paid yet or pay for hours in advance.',
  );
}

// [phone]: its tiles show no method: the sentence leaves it out.
String paymentsTourHistory({required bool self, String? gender, bool phone = false})
{
  final String made = self
      ? tr("tutti i pagamenti che hai effettuato verso l'associazione", 'all the payments you have made to the Association')
      : (isEnglish ? 'all the payments made for ${_yours(gender)}' : 'tutti i pagamenti effettuati per ${_yours(gender)}');
  final String how = phone ? '' : tr(', con la data e la modalità di pagamento', ', with the date and method of payment');

  return isEnglish
      ? 'The table shows, year by year, $made$how, as well as the items still to pay.'
      : 'La tabella riporta, anno per anno, $made$how, oltre alle voci ancora da pagare.';
}

String paymentsTourEmpty({required bool self, String? gender})
{
  if (self)
  {
    return tr(
      "Qui troverai, anno per anno, tutti i pagamenti che hai effettuato verso l'associazione, con la data e la "
          'modalità di pagamento.',
      "Here you'll find, year by year, all the payments you have made to the Association, with the date and method of "
          'payment.',
    );
  }

  return isEnglish
      ? "Here you'll find, year by year, all the payments made for ${_yours(gender)}, with the date and method of payment."
      : 'Qui troverai, anno per anno, tutti i pagamenti effettuati per ${_yours(gender)}, con la data e la '
          'modalità di pagamento.';
}

String get kPaymentsTourToOwnClick => tr('Clicca «Personali».', 'Click “Personal”.');
String get kPaymentsTourToOwnTap => tr('Tocca «Personali».', 'Tap “Personal”.');

String get kPaymentsTourOwn => tr(
  'Qui trovi le tue quote annuali, con la data e la modalità di pagamento, e puoi saldare quelle ancora da pagare.',
  'Here you find your annual fees, with the date and method of payment, and you can pay those still due.',
);

String get kPaymentsTourOpenClick =>
    tr('Clicca su un pagamento per vederne i dettagli.', 'Click a payment to see its details.');
String get kPaymentsTourOpenTap => tr('Tocca un pagamento per vederne i dettagli.', 'Tap a payment to see its details.');

String get kPaymentsTourFacts =>
    tr("Qui trovi l'importo, la data e la modalità del pagamento.", 'Here you find the amount, date and method of the payment.');

String get kPaymentsTourToLessons => tr('Tocca «Lezioni».', 'Tap “Lessons”.');

String get kPaymentsTourCloseClick =>
    tr('Clicca la × per chiudere la finestra.', 'Click the × to close the window.');

// The lessons card of the payment open: what its lessons are to it.
String paymentsTourLessons(PaymentHistoryRow row)
{
  if (row.isPackage)
  {
    return tr(
      'Qui trovi le lezioni scalate dal pacchetto, con le ore rimaste dopo ciascuna.',
      'Here you find the lessons taken from the package, with the hours left after each.',
    );
  }

  if (row.isAhead)
  {
    return tr(
      'Qui trovi le lezioni scalate dalle ore pagate in anticipo, con le ore rimaste dopo ciascuna.',
      'Here you find the lessons taken from the hours paid in advance, with the hours left after each.',
    );
  }

  if (row.isMonth)
  {
    return tr('Qui trovi le lezioni svolte nel mese pagato.', 'Here you find the lessons held in the month paid.');
  }

  return tr(
    'Qui trovi le lezioni coperte da questo pagamento, con il costo di ciascuna.',
    'Here you find the lessons this payment covers, with the cost of each.',
  );
}

// ---------------------------------------------------------------- the «PAGA» window and sheet

String get kPayTourOwed => tr(
  "Qui trovi i pagamenti dovuti verso l'associazione: puoi selezionare le voci che vuoi pagare ora.",
  'Here you find the payments due to the Association: you can select the items you want to pay now.',
);

String get kPayTourDaysClick =>
    tr('Per le ore puoi scegliere anche i singoli giorni.', 'For hours you can also choose single days.');
String get kPayTourDaysTap => tr('Tocca la freccia per vedere i singoli giorni.', 'Tap the arrow to see the single days.');

// What «Altri pagamenti» holds for the tariff in force; [weekend] while online hours at the weekend can be
// paid ahead there too.
String payTourOthers(StudentTariffItem tariff, {bool weekend = false})
{
  final String also = weekend
      ? ' ${tr(
          'Puoi inoltre pagare in anticipo le ore online nel weekend, che verranno scalate appena svolte.',
          'You can also pay for online hours at the weekend in advance, which will be deducted as soon as they are '
              'held.',
        )}'
      : '';

  if (tariff.isPackage)
  {
    return tr(
          'Qui puoi rinnovare il pacchetto alle condizioni della tariffa in vigore. Puoi anche pagare in anticipo un '
              'rinnovo: il nuovo pacchetto inizierà automaticamente appena terminato quello in corso.',
          'Here you can renew the package on the terms of the current rate. You can also pay for a renewal in '
              'advance: the new package will start automatically as soon as the current one ends.',
        ) +
        also;
  }

  if (tariff.isMonthly)
  {
    return tr(
          'Qui puoi pagare la quota mensile. Puoi anche pagare in anticipo il rinnovo del mese successivo.',
          "Here you can pay the monthly fee. You can also pay the next month's renewal in advance.",
        ) +
        also;
  }

  if (weekend)
  {
    return tr(
      'Qui puoi pagare in anticipo delle ore di lezione, anche online nel weekend: verranno scalate '
          'automaticamente appena verranno svolte.',
      'Here you can pay for lesson hours in advance, online at the weekend too: they will be deducted '
          'automatically as soon as they are held.',
    );
  }

  return tr(
    'Qui puoi pagare in anticipo delle ore di lezione: verranno scalate automaticamente appena verranno svolte.',
    'Here you can pay for lesson hours in advance: they will be deducted automatically as soon as they are held.',
  );
}

String get kPayTourProceed => tr(
  'Con «PROCEDI AL PAGAMENTO» passerai a Stripe, dove potrai pagare in modo sicuro.',
  'With “PROCEED TO PAYMENT” you will go to Stripe, where you can pay securely.',
);
