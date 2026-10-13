import '../../shared/widgets/mobile_tour.dart';

const String _title = 'Impostazioni';

// Bump the version on every change to the tour.
const String _slug = 'settings';
const int _version = 1;

const String _about =
    "Nelle impostazioni, puoi personalizzare l'aspetto dell'applicazione e alcune preferenze di utilizzo, modificare "
    "la password e gestire i dispositivi su cui hai effettuato l'accesso. Puoi inoltre consultare i Termini di servizio "
    "e l'Informativa sulla privacy, nonché scaricare lo Statuto e il Regolamento dell'Associazione. Infine, puoi "
    "inviare un feedback o segnalare eventuali problemi riscontrati durante l'utilizzo dell'applicazione.";

// One message about the whole page, nothing singled out.
MobileTour settingsTour()
{
  return const MobileTour(
    slug: _slug,
    title: _title,
    version: _version,
    steps: [MobileTourStep(text: _about, lightsAll: true)],
  );
}
