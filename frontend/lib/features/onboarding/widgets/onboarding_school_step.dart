import 'package:flutter/material.dart';

import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';
import '../../people/tabs/person_schools_tab.dart';
import '../../people/widgets/person_detail_widgets.dart';
import '../../people/widgets/school_enrollment_edit_row.dart';

const double _cardMaxWidth = 1240;

class OnboardingSchoolStep extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  final Widget footer;

  const OnboardingSchoolStep({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.footer,
  });

  @override
  State<OnboardingSchoolStep> createState() => _OnboardingSchoolStepState();
}

class _OnboardingSchoolStepState extends State<OnboardingSchoolStep>
{
  int _index = 0;
  bool _movingForward = true;

  void _turn(int to)
  {
    setState(()
    {
      _movingForward = to > _index;
      _index = to;
    });
  }

  Widget _buildYears(List<SchoolEnrollmentItem> years)
  {
    if (years.isEmpty)
    {
      return const PersonEmptyState(message: 'Nessun anno scolastico registrato.');
    }

    // A new record starts from its first card.
    final int index = _index.clamp(0, years.length - 1);
    final bool isCurrent = years[index].startYear == currentSchoolYearStart();

    return AppCarouselFrame(
      index: index,
      movingForward: _movingForward,
      maxContentWidth: _cardMaxWidth,
      canGoBack: index > 0,
      canGoForward: index < years.length - 1,
      onBack: () => _turn(index - 1),
      onForward: () => _turn(index + 1),
      header: PersonSectionTitle(
        isCurrent ? 'Anno scolastico attuale' : 'Anno scolastico passato',
      ),
      child: SizedBox(
        width: double.infinity,
        child: schoolEnrollmentCard(years[index], years, isCurrent: isCurrent),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final years = [...?widget.person.schoolEnrollments]
      ..sort((a, b) => b.startYear.compareTo(a.startYear));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pageTransitionBlocks([
          _buildYears(years),
          const SizedBox(height: kPersonSectionGap),
          Center(
            child: AppGradientButton(
              label: 'MODIFICA ANNI SCOLASTICI',
              icon: Icons.edit_rounded,
              onPressed: () => showEditSchoolsDialog(
                context,
                person: widget.person,
                onUpdate: widget.onUpdate,
              ),
            ),
          ),
          const SizedBox(height: kPersonSectionGap),
          widget.footer,
        ]),
      ),
    );
  }
}
