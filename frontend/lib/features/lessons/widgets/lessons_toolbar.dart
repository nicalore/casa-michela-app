import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/tab_layout.dart';

// The height and radius the head of a list page gives its button, so it stands
// level with the search field beside it.
const double _actionHeight = 50;
const double _actionRadius = 25;
const double _actionFontSize = 14;

// Which of the two lists of a day is on screen. They are not two sections of
// the module — they are one day looked at from two sides — so what chooses
// between them stands over the content and not in the rail.
enum LessonsDayView
{
  availability,
  bookings,
}

// The band a day is worked from: which side you are on, what you are looking
// for, and the one thing you can add.
//
// The two sides are the same segmented control the app changes view with
// everywhere else — the sections of a person's page, the cards of a step in the
// person wizard — so this reads as the same gesture rather than as a control of
// its own. They stand at the head of the band, where a tab bar begins, and the
// field and the button after them are the ones every other list page has.
class LessonsToolbar extends StatelessWidget
{
  final LessonsDayView view;
  final ValueChanged<LessonsDayView> onViewSelected;

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;

  final String actionLabel;
  final VoidCallback onAction;

  const LessonsToolbar({
    super.key,
    required this.view,
    required this.onViewSelected,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchHint,
    required this.actionLabel,
    required this.onAction,
  });

  Widget _buildTabs()
  {
    return AppSegmentedTabs(
      labels: const ['Disponibilità', 'Prenotazioni'],
      selectedIndex: view.index,
      onSelected: (index) => onViewSelected(LessonsDayView.values[index]),
      // The air under them belongs to the band, which puts it there itself.
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildSearch()
  {
    return AppSearchField(
      controller: searchController,
      onChanged: onSearchChanged,
      hintText: searchHint,
    );
  }

  Widget _buildAction()
  {
    return AppGradientButton(
      label: actionLabel,
      icon: Icons.add_rounded,
      height: _actionHeight,
      // Half its own height: the shape of the search field it stands beside.
      radius: _actionRadius,
      fontSize: _actionFontSize,
      onPressed: onAction,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        // The same width every list page of the app splits its head at, asked
        // of the content rather than of the window: under it three controls in
        // a row leave the field too little to be a field, so the tabs take a
        // line of their own and the two below them stack in their turn.
        if (AppBreakpoints.fromWidth(constraints.maxWidth).isCompact)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _buildTabs(),
              ),
              const SizedBox(height: 16),
              // Below the breakpoint this stacks the field and the button and
              // hands the button the full width, which is what the association
              // pages do at the same width.
              TabHeaderRow(search: _buildSearch(), action: _buildAction()),
            ],
          );
        }

        return Row(
          children: [
            _buildTabs(),
            const SizedBox(width: 20),
            Expanded(child: _buildSearch()),
            const SizedBox(width: 24),
            _buildAction(),
          ],
        );
      },
    );
  }
}
