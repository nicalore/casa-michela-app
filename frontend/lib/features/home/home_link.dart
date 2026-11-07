import '../../core/utils/time_bucket.dart';

// Where a band or a figure of the home leads, on the desktop and on mobile alike.
// [pupil]: the child it is about, on a parent's home.
sealed class HomeLink
{
  final String? pupil;

  const HomeLink({this.pupil});
}

// Disponibilità for a teacher, Prenotazioni for the others, on the running week.
final class HomeWeekLink extends HomeLink
{
  const HomeWeekLink({super.pupil});
}

// Today's calendar on that band.
final class HomeCalendarLink extends HomeLink
{
  final TimeBucket band;

  const HomeCalendarLink(this.band, {super.pupil});
}

// Statistiche personali on this month: one's own, or the child's.
final class HomeStatsLink extends HomeLink
{
  const HomeStatsLink({super.pupil});
}

HomeLink homeBandLink(TimeBucket band, {required bool isPublished, String? pupil})
{
  return isPublished ? HomeCalendarLink(band, pupil: pupil) : HomeWeekLink(pupil: pupil);
}
