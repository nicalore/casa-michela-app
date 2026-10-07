import 'package:flutter/material.dart';

import '../../../features/people/models/person_face.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import 'mobile_home_view.dart';
import 'mobile_pupil_day.dart';
import 'widgets/mobile_child_cards.dart';
import 'widgets/mobile_notices_list.dart';

const String _noPupils = 'Nessuno studente associato.';

const double _cardGap = 12;
const double _rowGap = 14;

// Alphabetical, so today's cards and the month's come in the same order.
List<T> _alphabetical<T>(List<T> items, PersonFace Function(T) faceOf)
{
  return [...items]..sort((a, b) => compareByName(faceOf(a), faceOf(b)));
}

// Data-free, for probes.
class MobileParentHomeView extends StatelessWidget
{
  final String firstName;
  final DateTime? birthDate;

  // Null when the day could not be read.
  final bool loadingDay;
  final MobileParentDay? day;

  // Null when the month could not be read.
  final bool loadingMonth;
  final List<MobileChildMonth>? month;

  final Future<void> Function() onRefresh;
  final PageController pageController;

  const MobileParentHomeView({
    super.key,
    required this.firstName,
    required this.birthDate,
    required this.loadingDay,
    required this.day,
    required this.loadingMonth,
    required this.month,
    required this.onRefresh,
    required this.pageController,
  });

  bool get _loading => loadingDay || loadingMonth;

  Widget _column(List<Widget> cards)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) const SizedBox(height: _cardGap),
          card,
        ],
      ],
    );
  }

  Widget _buildToday()
  {
    if (loadingDay)
    {
      return const MobileWaiting();
    }

    final MobileParentDay? today = day;

    if (today == null)
    {
      return const MobileHomeStatus(kMobileDayUnavailable);
    }

    if (today.isClosed)
    {
      return const MobileHomeClosed();
    }

    if (today.children.isEmpty)
    {
      return const MobileHomeStatus(_noPupils);
    }

    return _column([
      for (final child in _alphabetical(today.children, (child) => child.face))
        MobileChildDayCard(child: child),
    ]);
  }

  Widget _buildMonth()
  {
    if (loadingMonth)
    {
      return const MobileWaiting();
    }

    final List<MobileChildMonth>? months = month;

    if (months == null)
    {
      return const MobileHomeStatus(kMobileMonthUnavailable);
    }

    if (months.isEmpty)
    {
      return const MobileHomeStatus(_noPupils);
    }

    return _column([
      for (final child in _alphabetical(months, (child) => child.face))
        MobileChildMonthCard(month: child),
    ]);
  }

  // One card per child, always: a closed or unread half says so.
  Widget _buildRows()
  {
    final MobileParentDay? today = day;
    final List<MobileChildMonth>? months = month;

    final Map<String, MobileChildDay> days = {
      for (final child in today?.children ?? const <MobileChildDay>[]) child.taxCode: child,
    };
    final Map<String, MobileChildMonth> monthsOf = {
      for (final child in months ?? const <MobileChildMonth>[]) child.taxCode: child,
    };

    final List<String> order = _alphabetical(
      [...days.keys, ...monthsOf.keys.where((taxCode) => !days.containsKey(taxCode))],
      (taxCode) => (days[taxCode]?.face ?? monthsOf[taxCode]!.face),
    );

    if (order.isEmpty)
    {
      if (today == null && months == null)
      {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [MobileHomeStatus(kMobileDayUnavailable), MobileHomeStatus(kMobileMonthUnavailable)],
        );
      }

      return const MobileHomeStatus(_noPupils);
    }

    final MobileCardNote? dayNote = switch (today)
    {
      null => const MobileCardNote(kMobileDayUnavailable),
      MobileParentDay(isClosed: true) =>
        const MobileCardNote(kMobileClosedTitle, icon: Icons.event_busy_rounded),
      _ => null,
    };

    final MobileCardNote? monthNote = months == null ? const MobileCardNote(kMobileMonthUnavailable) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, taxCode) in order.indexed) ...[
          if (i > 0) const SizedBox(height: _rowGap),
          MobileChildRowCard(
            face: days[taxCode]?.face ?? monthsOf[taxCode]!.face,
            titles: (MobileHomeFrame.pageNames[0], MobileHomeFrame.pageNames[1]),
            day: days[taxCode],
            dayNote: dayNote,
            month: monthsOf[taxCode],
            monthNote: monthNote,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    const List<String> names = MobileHomeFrame.pageNames;

    return MobileHomeFrame(
      firstName: firstName,
      birthDate: birthDate,
      onRefresh: onRefresh,
      pageController: pageController,
      pages: () => [
        MobileLoadSwitcher(child: _buildToday()),
        MobileLoadSwitcher(child: _buildMonth()),
        const MobileNoticesList(),
      ],
      tabletBody: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileLoadSwitcher(
            waiting: _loading,
            child: _loading ? const MobileWaiting() : _buildRows(),
          ),
          const SizedBox(height: MobileHomeFrame.sectionGap),
          MobileHomeSection(title: names[2], child: const MobileNoticesList()),
        ],
      ),
    );
  }
}
