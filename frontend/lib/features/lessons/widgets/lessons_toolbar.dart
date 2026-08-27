import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/tab_layout.dart';

const double _actionHeight = 50;
const double _actionRadius = 25;
const double _actionFontSize = 14;

enum LessonsDayView
{
  availability,
  bookings,
}

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
