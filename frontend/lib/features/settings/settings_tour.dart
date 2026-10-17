import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';
import 'utils/settings_strings.dart';

// Said on the phone too.
const String kSettingsTourText =
    "Nelle impostazioni, puoi personalizzare l'aspetto dell'applicazione e alcune preferenze di utilizzo, modificare "
    "la password e gestire i dispositivi su cui hai effettuato l'accesso. Puoi inoltre consultare i Termini di servizio "
    "e l'Informativa sulla privacy, nonché scaricare lo Statuto e il Regolamento dell'Associazione. Infine, puoi "
    "inviare un feedback o segnalare eventuali problemi riscontrati durante l'utilizzo dell'applicazione.";

// Bump the version on every change to the tour.
// One message about the whole page: nothing lit, the card in the middle.
const DesktopTour desktopSettingsTour = DesktopTour(
  slug: 'settings',
  title: kSettingsTitle,
  version: 1,
  steps: [DesktopTourStep(text: kSettingsTourText)],
);

// The same for every role having tours.
void startSettingsTour(BuildContext context)
{
  final identity = ApiService().lastKnownIdentity;
  final String? taxCode = identity?.taxCode;

  if (taxCode == null || !kDesktopTourRoles.contains(identity?.activeRole))
  {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_)
  {
    if (context.mounted)
    {
      startDesktopTourOnce(context, taxCode: taxCode, tour: desktopSettingsTour);
    }
  });
}
