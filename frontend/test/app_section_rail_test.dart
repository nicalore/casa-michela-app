import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/shared/widgets/app_section_rail.dart';

// The Associazione rail, the only one with more than one group, and the one
// whose indices the page hands straight to its IndexedStack.
const List<RailGroup> _groups = [
  RailGroup(entries: ['Scuole']),
  RailGroup(
    title: 'Didattica',
    entries: ['Discipline interne', 'Materie ministeriali', 'Percorsi di studio'],
  ),
  RailGroup(title: 'Orari', entries: ['In presenza', 'Online']),
];

Future<List<int>> _pumpRail(WidgetTester tester, {int selectedIndex = 0}) async
{
  final selections = <int>[];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: AppSectionRail(
            title: 'Associazione',
            groups: _groups,
            selectedIndex: selectedIndex,
            onSelected: selections.add,
          ),
        ),
      ),
    ),
  );

  return selections;
}

void main()
{
  setUpAll(()
  {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppSectionRail', ()
  {
    testWidgets('shows the title, the group headings and every entry', (tester) async
    {
      await _pumpRail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Associazione'), findsOneWidget);
      expect(find.text('DIDATTICA'), findsOneWidget);
      expect(find.text('ORARI'), findsOneWidget);

      for (final group in _groups)
      {
        for (final entry in group.entries)
        {
          expect(find.text(entry), findsOneWidget);
        }
      }
    });

    // The indices are what the page turns straight into an IndexedStack index,
    // so a heading quietly taking a number of its own would show the wrong
    // section rather than fail.
    testWidgets('numbers the entries only, headings excluded', (tester) async
    {
      final selections = await _pumpRail(tester);

      await tester.tap(find.text('Scuole'));
      await tester.tap(find.text('Discipline interne'));
      await tester.tap(find.text('Percorsi di studio'));
      await tester.tap(find.text('In presenza'));
      await tester.tap(find.text('Online'));

      expect(selections, [0, 1, 3, 4, 5]);
    });

    // Impostazioni has the other shape: a titled group first, then a run of
    // entries standing on their own. The numbering has to carry straight
    // through the two, since the page turns it into a stack index by hand.
    testWidgets('numbers a run standing after a group', (tester) async
    {
      final selections = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: AppSectionRail(
                title: 'Impostazioni',
                groups: const [
                  RailGroup(
                    title: 'Profilo',
                    entries: ['Informazioni personali', 'Informazioni associative'],
                  ),
                  RailGroup(entries: ['Account', 'Informazioni']),
                ],
                selectedIndex: 0,
                onSelected: selections.add,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Informazioni associative'));
      await tester.tap(find.text('Account'));
      await tester.tap(find.text('Informazioni'));

      expect(selections, [1, 2, 3]);
    });

    // A heading is a label, not a destination: tapping it must do nothing at
    // all, or the group would behave like the sixth section.
    testWidgets('a heading is not clickable', (tester) async
    {
      final selections = await _pumpRail(tester);

      await tester.tap(find.text('DIDATTICA'), warnIfMissed: false);
      await tester.pump();

      expect(selections, isEmpty);
    });

    // The mark is squeezed by a transform, so it must not take part in layout:
    // whichever entry is current, the rail keeps the same size and the entries
    // stay where they are.
    testWidgets('the current entry does not move the ones around it', (tester) async
    {
      await _pumpRail(tester);
      await tester.pumpAndSettle();

      final railAtRest = tester.getSize(find.byType(AppSectionRail));
      final entryAtRest = tester.getTopLeft(find.text('Online'));

      await _pumpRail(tester, selectedIndex: 5);
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppSectionRail)), railAtRest);
      expect(tester.getTopLeft(find.text('Online')), entryAtRest);
    });
  });
}
