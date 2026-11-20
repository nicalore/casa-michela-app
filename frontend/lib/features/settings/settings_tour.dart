import 'package:flutter/widgets.dart';

import '../../core/language/app_language.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/desktop_tour.dart';
import 'utils/settings_strings.dart';

// Said on the phone too.
String get kSettingsTourText => tr(
    "Nelle impostazioni, puoi personalizzare l'aspetto dell'applicazione e alcune preferenze di utilizzo, modificare "
    "la password e gestire i dispositivi su cui hai effettuato l'accesso. Puoi inoltre consultare i Termini di servizio "
    "e l'Informativa sulla privacy, nonché scaricare lo Statuto e il Regolamento dell'Associazione. Infine, puoi "
    "inviare un feedback o segnalare eventuali problemi riscontrati durante l'utilizzo dell'applicazione.",
    'In the settings you can customise how the app looks and some of its preferences, change your '
    'password and manage the devices you have signed in on. You can also read the Terms of service and the '
    'Privacy policy, and download the Statute and the Regulations of the Association. Finally, you can send '
    'feedback or report any problems you run into while using the app.',
);

// Bump the version on every change to the tour.
// One message about the whole page: nothing lit, the card in the middle.
DesktopTour get desktopSettingsTour => DesktopTour(
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
