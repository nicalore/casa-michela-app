import 'package:flutter/material.dart';

import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../people/models/person_item.dart';
import '../../people/widgets/teacher_competences_editor.dart';

const double _maxWidth = 960;

const double _filtersGap = 20;
const double _footerGap = 24;

// The teacher goes straight to picking, laid out like the edit window: the
// search and filters stay put on the page, the catalogue scrolls between them
// and the buttons, so nothing has to be scrolled to be reached.
class OnboardingSubjectsStep extends StatelessWidget
{
  final PersonItem person;

  final ValueChanged<TeacherCompetencesDraft> onChanged;

  final Widget footer;

  const OnboardingSubjectsStep({
    super.key,
    required this.person,
    required this.onChanged,
    required this.footer,
  });

  @override
  Widget build(BuildContext context)
  {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: TeacherCompetencesEditor(
          person: person,
          onChanged: onChanged,
          builder: (context, filters, list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTransitionItem(slot: PageTransitionItem.header, child: filters),
              const SizedBox(height: _filtersGap),
              Expanded(
                child: PageTransitionItem(
                  slot: PageTransitionItem.list,
                  child: AppDialogPill(expand: true, child: list),
                ),
              ),
              const SizedBox(height: _footerGap),
              PageTransitionItem(slot: PageTransitionItem.list + 1, child: footer),
            ],
          ),
        ),
      ),
    );
  }
}
