import 'package:flutter/material.dart';

import '../../../features/dashboard/widgets/dashboard_birthdays_section.dart';
import '../../../features/home/widgets/home_month_section.dart';
import '../../shared/widgets/mobile_empty_card.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import 'mobile_home_view.dart';
import 'widgets/mobile_admin_cards.dart';
import 'widgets/mobile_month_figures.dart';
import 'widgets/mobile_notices_list.dart';

const List<String> kAdminHomePages = ['Oggi', 'Questo mese', 'Compleanni', 'Notifiche e avvisi'];

// The desktop card's wording.
const String _noBirthdays = 'Nessun compleanno in arrivo.';

// Tablets: as many as the desktop card, beside the month.
const int _besideBirthdays = 4;

// Data-free, for probes.
class MobileAdminHomeView extends StatelessWidget
{
  final String firstName;
  final DateTime? birthDate;

  // [day] is null when it could not be read.
  final bool loadingDay;
  final List<MobileAdminBand>? day;

  // [month] is null when it could not be read.
  final bool loadingMonth;
  final List<HomeFigure>? month;

  final bool loadingBirthdays;
  final List<DashboardBirthday> birthdays;

  final Future<void> Function() onRefresh;
  final PageController pageController;

  final MobileHomeNotices notices;

  const MobileAdminHomeView({
    super.key,
    required this.firstName,
    required this.birthDate,
    required this.loadingDay,
    required this.day,
    required this.loadingMonth,
    required this.month,
    required this.loadingBirthdays,
    required this.birthdays,
    required this.onRefresh,
    required this.pageController,
    this.notices = const MobileHomeNotices(),
  });

  Widget _buildToday({bool roomy = false})
  {
    if (loadingDay)
    {
      return const MobileWaiting();
    }

    final List<MobileAdminBand>? bands = day;

    return bands == null
        ? const MobileHomeStatus(kMobileDayUnavailable)
        : MobileAdminDayCards(bands: bands, roomy: roomy);
  }

  Widget _buildMonth({bool compact = false})
  {
    if (loadingMonth)
    {
      return const MobileWaiting();
    }

    final List<HomeFigure>? figures = month;

    return figures == null
        ? const MobileHomeStatus(kMobileMonthUnavailable)
        : MobileAssociationMonthFigures(figures: figures, compact: compact);
  }

  Widget _buildBirthdays({bool compact = false})
  {
    if (loadingBirthdays)
    {
      return const MobileWaiting();
    }

    if (birthdays.isEmpty)
    {
      // Beside the month on tablets, a whole page on phones.
      return compact
          ? const MobileHomeStatus(_noBirthdays)
          : const Center(child: MobileEmptyCard(icon: Icons.cake_rounded, message: _noBirthdays, tablet: false));
    }

    return MobileBirthdayCards(
      birthdays: compact ? birthdays.take(_besideBirthdays).toList() : birthdays,
      compact: compact,
    );
  }

  // Today on the left, as tall as the month and the birthdays stacked beside it.
  Widget _buildTablet()
  {
    const List<String> names = kAdminHomePages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MobileHomeSection(
                  title: names[0],
                  fill: true,
                  child: MobileLoadSwitcher(child: _buildToday(roomy: true)),
                ),
              ),
              const SizedBox(width: MobileHomeFrame.columnGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MobileHomeSection(
                      title: names[1],
                      child: MobileLoadSwitcher(child: _buildMonth(compact: true)),
                    ),
                    const SizedBox(height: MobileHomeFrame.sectionGap),
                    MobileHomeSection(
                      title: names[2],
                      child: MobileLoadSwitcher(child: _buildBirthdays(compact: true)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MobileHomeFrame.sectionGap),
        MobileHomeSection(title: names[3], child: MobileNoticesList(notices: notices)),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileHomeFrame(
      firstName: firstName,
      birthDate: birthDate,
      onRefresh: onRefresh,
      pageController: pageController,
      names: kAdminHomePages,
      tourTabs: null,
      tourPages: null,
      scrollingNames: true,
      emptyPages: {if (!loadingBirthdays && birthdays.isEmpty) 2},
      pages: () => [
        MobileLoadSwitcher(child: _buildToday()),
        MobileLoadSwitcher(child: _buildMonth()),
        MobileLoadSwitcher(child: _buildBirthdays()),
        MobileNoticesList(notices: notices),
      ],
      tabletBody: (_) => _buildTablet(),
    );
  }
}
