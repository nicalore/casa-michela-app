import '../../../features/settings/settings_tour.dart' show kSettingsTourText;
import '../../shared/widgets/mobile_tour.dart';

const String _title = 'Impostazioni';

// Bump the version on every change to the tour.
const String _slug = 'settings';
const int _version = 1;

// One message about the whole page, nothing singled out.
MobileTour settingsTour()
{
  return const MobileTour(
    slug: _slug,
    title: _title,
    version: _version,
    steps: [MobileTourStep(text: kSettingsTourText, lightsAll: true)],
  );
}
