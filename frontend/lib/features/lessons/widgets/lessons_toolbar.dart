import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/tab_layout.dart';

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

  Widget _buildTabs(bool dense)
  {
    return AppSegmentedTabs(
      labels: const ['Disponibilità', 'Prenotazioni'],
      selectedIndex: view.index,
      onSelected: (index) => onViewSelected(LessonsDayView.values[index]),
      padding: EdgeInsets.zero,
      height: dense ? 40 : 44,
      fontSize: dense ? 13.5 : 14,
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
    return tabActionButton(label: actionLabel, onPressed: onAction);
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (AppBreakpoints.isNarrowWidth(constraints.maxWidth))
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _buildTabs(dense),
              ),
              SizedBox(height: dense ? 10 : 16),
              TabHeaderRow(search: _buildSearch(), action: _buildAction()),
            ],
          );
        }

        return Row(
          children: [
            _buildTabs(dense),
            SizedBox(width: dense ? 12 : 20),
            Expanded(child: _buildSearch()),
            SizedBox(width: dense ? 12 : 24),
            _buildAction(),
          ],
        );
      },
    );
  }
}
