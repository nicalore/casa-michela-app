import 'package:flutter/material.dart';

import '../../../core/utils/time_bucket.dart';
import '../../shared/widgets/mobile_action_circle.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_availability_draft.dart';
import 'mobile_availability_week.dart';

const String _title = 'Disponibilità';

// Bump a version on every change to that tour.
const String _slug = 'availability';
const int _version = 10;

// What a day card may show; each has a one-step tour for when the main one does not show it.
enum AvailabilityMark { slots, add, edit, lock }

const Map<AvailabilityMark, int> _markVersions = {
  AvailabilityMark.slots: 2,
  AvailabilityMark.add: 2,
  AvailabilityMark.edit: 2,
  AvailabilityMark.lock: 6,
};

String availabilityTourWeek(int page) => 'availability.week.$page';
String availabilityTourTab(int page) => 'availability.tab.$page';
String availabilityTourMark(AvailabilityMark mark, int page) => 'availability.${mark.name}.$page';

const String kAvailabilityTourInfo = 'availability.info';

const EdgeInsets kAvailabilityTourWeekInflate = EdgeInsets.all(12);
const double kAvailabilityTourWeekRadius = 22;

const String _thisWeek = 'Qui puoi vedere le disponibilità che hai dato questa settimana.';
const String _toNextWeek = 'Tocca «Settimana prossima».';
const String _nextWeek = 'Qui puoi dare le disponibilità per la settimana prossima, che si sblocca il venerdì alle 20:00.';
const String _info =
    'In $kMobileTourGlyph trovi le scadenze entro cui dare o modificare le disponibilità: toccalo per leggerle.';

const Map<AvailabilityMark, String> _markTexts = {
  AvailabilityMark.slots:
      "Le lezioni in presenza sono contrassegnate dal colore verde e dall'icona di una casa, mentre quelle online sono "
      "indicate in arancione e con l'icona di una videocamera.",
  AvailabilityMark.add: 'Con $kMobileTourGlyph puoi aggiungere una disponibilità per un giorno.',
  AvailabilityMark.edit: 'Con $kMobileTourGlyph puoi modificare o eliminare una disponibilità.',
  AvailabilityMark.lock: 'Il lucchetto indica che non è più possibile aggiungere o modificare la disponibilità.',
};

const Duration _pageBack = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

// What the cards of a week show; empty for a week still locked.
Set<AvailabilityMark> availabilityMarks(List<MobileAvailabilityDay> days)
{
  return {
    if (days.any((day) => !day.isClosed && day.bands.any((band) => band.showsColours))) AvailabilityMark.slots,
    if (days.any((day) => day.isEditable && !day.hasSlots)) AvailabilityMark.add,
    if (days.any((day) => day.isEditable && day.hasSlots)) AvailabilityMark.edit,
    if (days.any((day) => !day.isClosed && day.bands.any((band) => band.showsLock))) AvailabilityMark.lock,
  };
}

Widget Function(double size)? _glyph(AvailabilityMark mark)
{
  return switch (mark)
  {
    AvailabilityMark.add => (size) => MobileActionCircle(icon: Icons.add_rounded, size: size, iconSize: size * 0.78),
    AvailabilityMark.edit =>
      (size) => MobileActionCircle(icon: Icons.edit_calendar_rounded, size: size, iconSize: size * 0.62),
    AvailabilityMark.slots || AvailabilityMark.lock => null,
  };
}

MobileTourStep _markStep(AvailabilityMark mark, int page)
{
  return MobileTourStep(
    text: _markTexts[mark]!,
    shown: [availabilityTourMark(mark, page)],
    glyph: _glyph(mark),
  );
}

(String, int) _markSeen(AvailabilityMark mark) => ('$_slug.${mark.name}', _markVersions[mark]!);

// Marks go on the first week having them; those in no week get their own tour.
MobileTour availabilityTour({
  required PageController pages,
  required Set<AvailabilityMark> thisWeek,
  required Set<AvailabilityMark> nextWeek,
})
{
  bool onPage(int index) => pages.hasClients && ((pages.page ?? 0) - index).abs() < _settled;

  void backTo(int index)
  {
    if (pages.hasClients)
    {
      pages.animateToPage(index, duration: _pageBack, curve: Curves.easeInOutCubic);
    }
  }

  List<MobileTourStep> marks(Set<AvailabilityMark> on, int page, {Set<AvailabilityMark> shownBefore = const {}})
  {
    return [
      for (final AvailabilityMark mark in AvailabilityMark.values)
        if (on.contains(mark) && !shownBefore.contains(mark)) _markStep(mark, page),
    ];
  }

  return MobileTour(
    slug: _slug,
    title: _title,
    version: _version,
    steps: [
      MobileTourStep(text: _thisWeek, shown: [availabilityTourWeek(0)]),
      ...marks(thisWeek, 0),
      MobileTourStep(
        text: _toNextWeek,
        touched: [availabilityTourTab(1)],
        watch: pages,
        reached: () => onPage(1),
        undo: () => backTo(0),
      ),
      MobileTourStep(text: _nextWeek, shown: [availabilityTourWeek(1)]),
      ...marks(nextWeek, 1, shownBefore: thisWeek),
      // Ends as the (i) sheet rises, which drops the menu bar.
      MobileTourStep(
        text: _info,
        touched: const [kAvailabilityTourInfo],
        glyph: MobileInfoButton.glyph,
        watch: MobileNavSheet.hidden,
        reached: () => MobileNavSheet.hidden.value,
      ),
    ],
    covers: [for (final AvailabilityMark mark in {...thisWeek, ...nextWeek}) _markSeen(mark)],
    coversIfClosed: [for (final AvailabilityMark mark in AvailabilityMark.values) _markSeen(mark)],
  );
}

// Only to ask whether the main tour was seen: its steps do not matter there.
MobileTour availabilityMainTour(PageController pages) => availabilityTour(pages: pages, thisWeek: const {}, nextWeek: const {});

MobileTour availabilityMarkTour(AvailabilityMark mark, int page)
{
  final (String slug, int version) = _markSeen(mark);

  return MobileTour(slug: slug, title: _title, version: version, steps: [_markStep(mark, page)]);
}

// The day sheet, opened from the edit button.
enum DaySheetMark { bin, band, day, edit }

// Bump a version on every change to that tour.
const String _sheetSlug = 'availability.day';
const int _sheetVersion = 3;

const Map<DaySheetMark, int> _sheetMarkVersions = {
  DaySheetMark.bin: 2,
  DaySheetMark.band: 2,
  DaySheetMark.day: 2,
  DaySheetMark.edit: 3,
};

const Map<DaySheetMark, String> _sheetTexts = {
  DaySheetMark.bin:
      'Il cestino ti permette di rimuovere un singolo orario tra quelli in cui hai indicato la tua disponibilità.',
  DaySheetMark.band: 'Puoi anche eliminare tutte le disponibilità che hai dato per una fascia oraria.',
  DaySheetMark.day: 'Se lo desideri, puoi eliminare direttamente tutte le disponibilità che hai dato per la giornata.',
  DaySheetMark.edit: 'Se vuoi modificare le disponibilità che hai già dato, tocca «Modifica».',
};

String daySheetTourTarget(DaySheetMark mark) => 'availability.sheet.${mark.name}';

(String, int) _sheetSeen(DaySheetMark mark) => ('$_sheetSlug.${mark.name}', _sheetMarkVersions[mark]!);

// "Modifica" opens the wizard if touched, or the tour just ends there.
MobileTourStep _sheetStep(DaySheetMark mark)
{
  final String target = daySheetTourTarget(mark);

  return mark == DaySheetMark.edit
      ? MobileTourStep(text: _sheetTexts[mark]!, touched: [target], tapMovesOn: true)
      : MobileTourStep(text: _sheetTexts[mark]!, shown: [target]);
}

MobileTour _sheetTour(String slug, int version, List<DaySheetMark> marks)
{
  return MobileTour(
    slug: slug,
    title: _title,
    version: version,
    steps: [for (final DaySheetMark mark in marks) _sheetStep(mark)],
    covers: [for (final DaySheetMark mark in marks) _sheetSeen(mark)],
    coversIfClosed: [for (final DaySheetMark mark in DaySheetMark.values) _sheetSeen(mark)],
    // The sheet closed under it: it comes back the next time.
    leave: MobileNavSheet.hidden,
    left: () => !MobileNavSheet.hidden.value,
  );
}

// The first time: every mark the sheet shows. Later: the marks shown for the first time, together.
Future<void> startDaySheetTour({required String taxCode, required Set<DaySheetMark> present}) async
{
  final List<DaySheetMark> marks = [
    for (final DaySheetMark mark in DaySheetMark.values)
      if (present.contains(mark)) mark,
  ];

  if (marks.isEmpty)
  {
    return;
  }

  final MobileTour first = _sheetTour(_sheetSlug, _sheetVersion, marks);

  if (!await isMobileTourSeen(taxCode: taxCode, tour: first))
  {
    await startMobileTourOnce(taxCode: taxCode, tour: first);

    return;
  }

  final List<DaySheetMark> fresh = [];

  for (final DaySheetMark mark in marks)
  {
    final (String slug, int version) = _sheetSeen(mark);

    if (!await isMobileTourSeen(taxCode: taxCode, tour: _sheetTour(slug, version, [mark])))
    {
      fresh.add(mark);
    }
  }

  if (fresh.isEmpty)
  {
    return;
  }

  final (String slug, int version) = _sheetSeen(fresh.first);

  await startMobileTourOnce(taxCode: taxCode, tour: _sheetTour(slug, version, fresh));
}

// Wizard adding or editing availability; each mark explained once, on the first page showing it.
enum WizardMark { days, yesNo, hours, add, bin, create, save }

// Bump a version on every change to that step.
const String _wizardSlug = 'availability.wizard';

const Map<WizardMark, int> _wizardVersions = {
  WizardMark.days: 4,
  WizardMark.yesNo: 6,
  WizardMark.hours: 4,
  WizardMark.add: 4,
  WizardMark.bin: 4,
  WizardMark.create: 3,
  WizardMark.save: 3,
};

const Map<WizardMark, String> _wizardTexts = {
  WizardMark.days: 'Puoi selezionare una data toccandola. Toccando una data barrata scopri perché non è disponibile.',
  WizardMark.yesNo:
      'Con il selettore dai o togli la tua disponibilità per la fascia oraria corrispondente (mattina, pomeriggio o sera).',
  WizardMark.hours: "Con + e − cambi gli orari in cui sei disponibile. Toccando l'ora puoi anche scriverla direttamente.",
  WizardMark.add:
      'Puoi indicare più orari di disponibilità nella stessa fascia. Ad esempio, dalle 14:00 alle 15:00 e dalle 17:00 alle 18:00.',
  WizardMark.bin: 'Puoi eliminare un orario in cui hai dato disponibilità toccando sul cestino.',
  WizardMark.create: 'Quando hai finito, tocca «Crea».',
  WizardMark.save: 'Quando hai finito, tocca «Salva».',
};

String wizardTourTarget(WizardMark mark, String page) => 'availability.wizard.${mark.name}.$page';

(String, int) _wizardSeen(WizardMark mark) => ('$_wizardSlug.${mark.name}', _wizardVersions[mark]!);

// Wizard news for its tour: last part touched, resting page (null while turning), or closed.
class WizardTourPulse extends ChangeNotifier
{
  WizardMark? used;
  String? page;
  bool gone = false;

  void use(WizardMark mark)
  {
    used = mark;
    notifyListeners();
  }

  void rest(String? key)
  {
    if (key != page)
    {
      page = key;
      notifyListeners();
    }
  }

  void leave()
  {
    gone = true;
    notifyListeners();
  }
}

Iterable<TimeBucket> _openBands(MobileAvailabilityDraft draft, MobileWizardStep step)
{
  return TimeBucket.values.where((bucket) => draft.windowFor(step.group, step.mode, bucket) != null);
}

int _stretches(MobileAvailabilityDraft draft, MobileWizardStep step, TimeBucket bucket)
{
  return draft.bandsOf(step.group)[step.mode]!.of(bucket).length;
}

// The band whose "Aggiungi orario" a tour lights: the first one given.
TimeBucket? wizardTourAddBand(MobileAvailabilityDraft draft, MobileWizardStep step)
{
  for (final TimeBucket bucket in _openBands(draft, step))
  {
    if (_stretches(draft, step, bucket) > 0)
    {
      return bucket;
    }
  }

  return null;
}

// Marks never seen on this page, now or after its touches; null page step: the days.
Future<void> startWizardTour({
  required MobileAvailabilityDraft draft,
  required MobileWizardStep? step,
  required String page,
  required bool Function() isLast,
  required WizardTourPulse pulse,
}) async
{
  final List<WizardMark> marks = step == null
      ? const [WizardMark.days]
      : [
          WizardMark.yesNo,
          WizardMark.hours,
          WizardMark.add,
          WizardMark.bin,
          draft.isEditing ? WizardMark.save : WizardMark.create,
        ];

  final List<WizardMark> fresh = [];

  for (final WizardMark mark in marks)
  {
    final (String slug, int version) = _wizardSeen(mark);
    final MobileTour alone = MobileTour(slug: slug, title: _title, version: version, steps: const []);

    if (!await isMobileTourSeen(taxCode: draft.taxCode, tour: alone))
    {
      fresh.add(mark);
    }
  }

  bool anyOpen() => step != null && _openBands(draft, step).isNotEmpty;
  bool anyGiven() => step != null && _openBands(draft, step).any((bucket) => _stretches(draft, step, bucket) > 0);
  bool anyBins() => step != null && _openBands(draft, step).any((bucket) => _stretches(draft, step, bucket) > 1);

  // Ahead of the yes/no step, the hours its touch may bring are counted.
  final bool asksYesNo = fresh.contains(WizardMark.yesNo);
  bool hoursMayCome() => asksYesNo && anyOpen();

  bool used(WizardMark mark) => pulse.used == mark;

  MobileTourStep build(WizardMark mark)
  {
    final String target = wizardTourTarget(mark, page);
    final String text = _wizardTexts[mark]!;
    final (String, int) seen = _wizardSeen(mark);

    return switch (mark)
    {
      WizardMark.days => MobileTourStep(
          text: text,
          touched: [target],
          watch: pulse,
          acted: () => used(mark) && draft.days.isNotEmpty,
          seen: seen,
        ),
      WizardMark.yesNo => MobileTourStep(
          text: text,
          touched: [target],
          watch: pulse,
          acted: () => used(mark),
          present: anyOpen,
          seen: seen,
        ),
      WizardMark.hours => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          watch: pulse,
          acted: () => used(mark),
          present: anyGiven,
          coming: hoursMayCome,
          seen: seen,
        ),
      WizardMark.add => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          tapMovesOn: true,
          present: anyGiven,
          coming: hoursMayCome,
          seen: seen,
        ),
      WizardMark.bin => MobileTourStep(
          text: text,
          touched: [target],
          reveal: target,
          tapMovesOn: true,
          present: anyBins,
          seen: seen,
        ),
      WizardMark.create || WizardMark.save => MobileTourStep(
          text: text,
          touched: [target],
          tapMovesOn: true,
          present: isLast,
          seen: seen,
        ),
    };
  }

  final List<MobileTourStep> steps = [for (final WizardMark mark in fresh) build(mark)];
  final int first = steps.indexWhere((step) => step.isPresent);

  // Closed while the marks were read.
  if (first < 0 || pulse.gone)
  {
    return;
  }

  final (String slug, int version) = _wizardSeen(fresh[first]);

  await startMobileTourOnce(
    taxCode: draft.taxCode,
    tour: MobileTour(
      slug: slug,
      title: _title,
      version: version,
      steps: steps,
      coversIfClosed: [for (final WizardMark mark in WizardMark.values) _wizardSeen(mark)],
      leave: pulse,
      left: () => pulse.gone || pulse.page != page,
    ),
  );
}
