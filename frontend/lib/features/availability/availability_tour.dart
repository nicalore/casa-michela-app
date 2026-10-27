import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';

const String kTourAvailabilityDays = 'availability.days';
const String kTourAvailabilityDeadlines = 'availability.deadlines';
const String kTourAvailabilityNext = 'availability.next';

const String kTourAvailabilityModes = 'availability.modes';
const String kTourAvailabilityAdd = 'availability.add';
const String kTourAvailabilityEdit = 'availability.edit';
const String kTourAvailabilityLock = 'availability.lock';
const String kTourAvailabilityBins = 'availability.bins';

const String kTourWizardDays = 'availability.wizard.days';
const String kTourWizardYesNo = 'availability.wizard.yesno';
const String kTourWizardHours = 'availability.wizard.hours';
const String kTourWizardAdd = 'availability.wizard.add';
const String kTourWizardBin = 'availability.wizard.bin';
const String kTourWizardSave = 'availability.wizard.save';

enum AvailabilityTourMark { modes, add, edit, lock, bins }

// True once the next week is on show; its tour step waits for it.
final ValueNotifier<bool> availabilityNextWeekShown = ValueNotifier(false);

// The wizard tells its tours: a date picked, and whether some band holds hours.
final ValueNotifier<int> availabilityWizardDaysPicked = ValueNotifier(0);
final ValueNotifier<bool> availabilityWizardHasHours = ValueNotifier(false);

const String _title = 'Disponibilità';

// Bump a version on every change to that tour.
const int _pageVersion = 5;
const int _nextWeekVersion = 3;
const int _daysVersion = 3;
const int _hoursVersion = 5;

const String _nextWeekSlug = 'availability.next';

// Parts that may appear later: in the main tour if present, else toured alone when first shown.
const (String, int) _modesSeen = ('availability.mark.modes', 1);
const (String, int) _addSeen = ('availability.mark.add', 1);
const (String, int) _editSeen = ('availability.mark.edit', 1);
const (String, int) _binsSeen = ('availability.mark.bins', 1);
const (String, int) _lockSeen = ('availability.mark.lock', 1);
const (String, int) _cursorsSeen = ('availability.wizard.cursors', 2);
const (String, int) _addHoursSeen = ('availability.wizard.add', 3);
const (String, int) _binSeen = ('availability.wizard.bin', 3);

const List<DesktopTourSide> _over = [DesktopTourSide.above, DesktopTourSide.below];
const List<DesktopTourSide> _below = [DesktopTourSide.below, DesktopTourSide.right, DesktopTourSide.above];
const List<DesktopTourSide> _beside = [
  DesktopTourSide.right,
  DesktopTourSide.left,
  DesktopTourSide.below,
  DesktopTourSide.above,
];
const List<DesktopTourSide> _leftFirst = [DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above];

bool _shown(String id) => isDesktopTourTargetShown(id);

// Admins giving hours for a teacher share this wizard: only teachers are toured.
// [still]: checked right before showing; false drops the tour (e.g. the card changed).
void startAvailabilityTour(BuildContext context, DesktopTour tour, {bool Function()? still})
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  if (taxCode == null || ApiService().lastKnownIdentity?.activeRole != 'TEACHER')
  {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_)
  {
    if (context.mounted)
    {
      startDesktopTourOnce(context, taxCode: taxCode, tour: tour, still: still);
    }
  });

  // Asked from another frame's callback, it still needs a frame to come.
  WidgetsBinding.instance.scheduleFrame();
}

// False when no identity is known.
Future<bool> availabilityTourSeen(DesktopTour tour) async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode != null && await isDesktopTourSeen(taxCode: taxCode, tour: tour);
}

// The parts on show not told yet, as one tour; null when none is due.
Future<DesktopTour?> _dueTour(List<DesktopTourStep> steps) async
{
  final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

  return taxCode == null ? null : dueDesktopTour(taxCode: taxCode, title: _title, steps: steps);
}

// The next week: its arrow, then its days; back from these turns the page to this week again.
List<DesktopTourStep> _nextWeekSteps(VoidCallback showThisWeek)
{
  return [
    DesktopTourStep(
      targets: const [kTourAvailabilityNext],
      text: 'Clicca la freccia per passare alla settimana prossima.',
      sides: _leftFirst,
      pad: 6,
      radius: 30,
      listen: availabilityNextWeekShown,
      reached: () => availabilityNextWeekShown.value,
      present: () => _shown(kTourAvailabilityNext) && !availabilityNextWeekShown.value,
      seen: (_nextWeekSlug, _nextWeekVersion),
    ),
    DesktopTourStep(
      targets: const [kTourAvailabilityDays],
      text: 'Qui puoi dare le disponibilità per la settimana prossima, che si sblocca il venerdì alle 20:00.',
      sides: _over,
      pad: 6,
      radius: 27,
      undo: showThisWeek,
      present: () => availabilityNextWeekShown.value,
      coming: () => _shown(kTourAvailabilityNext),
      seen: (_nextWeekSlug, _nextWeekVersion),
    ),
  ];
}

// Radius = the part's corner + half the pad; the hole adds the other half, so it is concentric.
final DesktopTourStep _modesStep = DesktopTourStep(
  targets: const [kTourAvailabilityModes],
  text: "Le lezioni in presenza sono contrassegnate dal colore verde e dall'icona di una casa, mentre quelle "
      "online sono indicate in arancione e con l'icona di una videocamera.",
  sides: _beside,
  pad: 10,
  radius: 16,
  reveal: true,
  present: () => _shown(kTourAvailabilityModes),
  seen: _modesSeen,
);

final DesktopTourStep _addStep = DesktopTourStep(
  targets: const [kTourAvailabilityAdd],
  text: 'Con «Aggiungi» puoi aggiungere una disponibilità per un giorno.',
  sides: _leftFirst,
  pad: 6,
  radius: 23,
  reveal: true,
  present: () => _shown(kTourAvailabilityAdd),
  seen: _addSeen,
);

final DesktopTourStep _editStep = DesktopTourStep(
  targets: const [kTourAvailabilityEdit],
  text: 'Con «Modifica» puoi modificare una disponibilità.',
  sides: _leftFirst,
  pad: 6,
  radius: 23,
  reveal: true,
  present: () => _shown(kTourAvailabilityEdit),
  seen: _editSeen,
);

final DesktopTourStep _binsStep = DesktopTourStep(
  targets: const [kTourAvailabilityBins],
  text: 'Passando con il mouse su un giorno compaiono i cestini: puoi eliminare un singolo orario, tutte le '
      "disponibilità di una fascia oraria o l'intera giornata.",
  sides: _below,
  pad: 6,
  radius: 27,
  reveal: true,
  present: () => _shown(kTourAvailabilityBins),
  seen: _binsSeen,
);

final DesktopTourStep _lockStep = DesktopTourStep(
  targets: const [kTourAvailabilityLock],
  text: 'Il lucchetto indica che non è più possibile aggiungere o modificare la disponibilità.',
  sides: _beside,
  pad: 6,
  radius: 10,
  reveal: true,
  present: () => _shown(kTourAvailabilityLock),
  seen: _lockSeen,
);

List<DesktopTourStep> get _pageMarks => [_modesStep, _addStep, _editStep, _binsStep, _lockStep];

// A part told once per tour, on this week or, once it is open, on the next.
DesktopTourStep _once(DesktopTourStep step, Map<(String, int), Object> told, {bool nextWeek = false})
{
  return desktopTourStepOnce(step, told, when: nextWeek ? () => availabilityNextWeekShown.value : null);
}

// With the next week open, its steps join this tour, then the parts only it shows.
DesktopTour availabilityPageTour({required VoidCallback showThisWeek})
{
  final Map<(String, int), Object> told = {};

  return DesktopTour(
    slug: 'availability',
    title: _title,
    version: _pageVersion,
    steps: [
      // The next week shown by a click while the tour got ready: back on this week.
      DesktopTourStep(
        targets: const [kTourAvailabilityDays],
        text: 'Qui puoi vedere le disponibilità che hai dato questa settimana.',
        sides: _over,
        pad: 6,
        radius: 27,
        enter: () => availabilityNextWeekShown.value ? showThisWeek() : null,
      ),
      for (final step in _pageMarks) _once(step, told),
      ..._nextWeekSteps(showThisWeek),
      for (final step in _pageMarks) _once(step, told, nextWeek: true),
      const DesktopTourStep(
        targets: [kTourAvailabilityDeadlines],
        text: 'Qui trovi le scadenze entro cui dare o modificare le disponibilità.',
        sides: _below,
        pad: 8,
        radius: 14,
      ),
    ],
  );
}

// The first time the arrow is there, for whoever saw the page before it unlocked.
DesktopTour availabilityNextWeekTour({required VoidCallback showThisWeek})
{
  return DesktopTour(
    slug: _nextWeekSlug,
    title: _title,
    version: _nextWeekVersion,
    steps: _nextWeekSteps(showThisWeek),
  );
}

Future<DesktopTour?> availabilityLatePageTour() => _dueTour(_pageMarks);

bool _always() => true;

final DesktopTour availabilityDaysTour = DesktopTour(
  slug: 'availability.wizard.days',
  title: _title,
  version: _daysVersion,
  steps: [
    // Picking a date ends it.
    DesktopTourStep(
      targets: const [kTourWizardDays],
      text: 'Puoi selezionare una data cliccandola. Passando il mouse su una data barrata scopri perché non è '
          'disponibile.',
      sides: _below,
      pad: 6,
      radius: 31,
      interactive: true,
      listen: availabilityWizardDaysPicked,
      reached: _always,
    ),
  ],
);

final DesktopTourStep _cursorsStep = DesktopTourStep(
  targets: const [kTourWizardHours],
  text: 'Trascinando i cursori cambi gli orari in cui sei disponibile.',
  sides: _beside,
  pad: 6,
  radius: 14,
  interactive: true,
  present: () => _shown(kTourWizardHours),
  seen: _cursorsSeen,
);

// A "Sì" gives the full band: the add button shows once the cursors leave some room.
final DesktopTourStep _addHoursStep = DesktopTourStep(
  targets: const [kTourWizardAdd],
  text: 'Puoi indicare più orari di disponibilità nella stessa fascia. Ad esempio, dalle 14:00 alle 15:00 e '
      'dalle 17:00 alle 18:00.',
  sides: _beside,
  pad: 6,
  radius: 19,
  present: () => _shown(kTourWizardAdd),
  seen: _addHoursSeen,
);

// A band with two hours shows a bin on each.
final DesktopTourStep _binStep = DesktopTourStep(
  targets: const [kTourWizardBin],
  text: 'Puoi eliminare un orario in cui hai dato disponibilità cliccando sul cestino.',
  sides: _beside,
  pad: 4,
  radius: 12,
  present: () => _shown(kTourWizardBin),
  seen: _binSeen,
);

// The first card with hours to give; a "Sì" on the switch brings the cursors in.
DesktopTour availabilityHoursTour({required bool editing})
{
  return DesktopTour(
    slug: 'availability.wizard.hours',
    title: _title,
    version: _hoursVersion,
    steps: [
      DesktopTourStep(
        targets: const [kTourWizardYesNo],
        text: 'Con il selettore dai o togli la tua disponibilità per la fascia oraria corrispondente (mattina, '
            'pomeriggio o sera).',
        sides: _beside,
        pad: 6,
        radius: 23,
        interactive: true,
        listen: availabilityWizardHasHours,
        reached: () => availabilityWizardHasHours.value,
        present: () => _shown(kTourWizardYesNo),
      ),
      DesktopTourStep(
        targets: _cursorsStep.targets,
        text: _cursorsStep.text,
        sides: _cursorsStep.sides,
        pad: _cursorsStep.pad,
        radius: _cursorsStep.radius,
        interactive: true,
        present: _cursorsStep.present,
        coming: () => !_shown(kTourWizardHours),
        seen: _cursorsSeen,
      ),
      _addHoursStep,
      _binStep,
      DesktopTourStep(
        targets: const [kTourWizardSave],
        text: editing ? 'Quando hai finito, clicca «Salva».' : 'Quando hai finito, clicca «Crea».',
        sides: _beside,
        pad: 6,
        radius: 17,
      ),
    ],
  );
}

Future<DesktopTour?> availabilityLateWizardTour() => _dueTour([_cursorsStep, _addHoursStep, _binStep]);
